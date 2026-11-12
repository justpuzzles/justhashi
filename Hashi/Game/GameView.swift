import SwiftUI

/// Hosts one game: board, chrome (timer, undo), persistence, and the win
/// moment (connectivity ripple → win card).
struct GameView: View {
    let game: HashiGame
    @Environment(ProgressStore.self) private var progress
    @Environment(MasteryTracker.self) private var mastery
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rippleDistances: [Int: Int]?
    @State private var showWinCard = false
    @State private var solve: SolveResult?
    @State private var warningIslands: Set<Int> = []
    @State private var hint: Hint?
    /// Set when the win card should hand off to the paywall on its way out.
    @State private var pendingPaywall: PaidFeature?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let hintEngine = HintEngine()

    private var boardSide: CGFloat {
        Metrics.boardWidth(regularWidth: horizontalSizeClass == .regular)
    }

    /// Free players keep the error check ("something here is wrong"); the
    /// teaching ladder is part of the unlock.
    private var hintPolicy: HintPolicy {
        entitlements.isUnlocked ? .full : .errorsOnly
    }

    /// The weekend Daily hands a free player a large board. The moment they
    /// solve it is the one moment worth making the case.
    private var offersUnlock: Bool {
        FeatureGate.shouldOfferUnlock(afterSolving: boardSize,
                                      wasDaily: game.dailyKey != nil,
                                      unlocked: entitlements.isUnlocked)
    }

    var body: some View {
        ZStack {
            SeaBackground(waves: true)
            #if os(tvOS)
            // Wide, not stacked: a television has width to spare and no
            // height, so the board takes the full height and the chrome sits
            // in a column beside it.
            HStack(alignment: .center, spacing: 60) {
                remoteSidebar
                board
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
            #else
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                board
                Spacer(minLength: 0)
            }
            #endif
        }
        .navigationTitleDisplay(.inline)
        .swipeBackDisabled()
        #if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .primaryTrailing) {
                HStack(spacing: 2) {
                    Button {
                        requestHint()
                    } label: {
                        Image(systemName: "lightbulb")
                    }
                    .disabled(game.phase != .playing)
                    .accessibilityLabel("Hint")
                    .help("Hint (⇧⌘H)")
                    Button {
                        undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!game.canUndo || game.phase != .playing)
                    .accessibilityLabel("Undo")
                    .help("Undo the last bridge (⌘Z)")
                }
            }
        }
        #endif
        #if os(macOS)
        // The menu bar's Undo and Hint act on this game. Mac only: nowhere
        // else has a menu bar to read it.
        .focusedSceneValue(\.boardActions, BoardActions(
            canUndo: game.canUndo && game.phase == .playing, undo: undo,
            canHint: game.phase == .playing, hint: requestHint))
        #endif
        #if !os(tvOS)
        .safeAreaInset(edge: .bottom) {
            if let hint { hintBanner(hint) }
        }
        #endif
        // The save must be written as the player works: board change, scene
        // backgrounding, and disappear. Saving only on phase change silently
        // loses everything — a game started and never paused never changes
        // phase. (Kakuro shipped that bug; both halves are pinned by tests.)
        .onChange(of: game.board) {
            persist()
            updateWarnings()
            // A hint describes the board it was asked on. Once the board moves
            // (a bridge, an undo) its Apply would place bridges for a position
            // that no longer exists, so it goes.
            if hint != nil {
                withAnimation(Motion.overlay) { hint = nil }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                game.pause()
                persist()
            } else {
                game.resume()
            }
        }
        .onAppear {
            game.showRemainingCapacity = progress.settings.showRemainingCount
            if progress.settings.autoCompleteForced {
                game.autoCompleteForcedIslands()
            }
            #if DEBUG
            // `-HashiHalfSolved`: the first half of the solution's bridges, so a
            // store screenshot shows a game under way. DEBUG only.
            if ProcessInfo.processInfo.arguments.contains("-HashiHalfSolved"),
               game.board.bridges.allSatisfy({ $0 == 0 }) {
                let placed = game.puzzle.edges.filter { game.puzzle.solution[$0.id] > 0 }
                for edge in placed.prefix(placed.count / 2) {
                    for _ in 0..<game.puzzle.solution[edge.id] { _ = game.cycleBridge(edge: edge.id) }
                }
            }
            #endif
        }
        .onDisappear {
            if game.phase != .won { persist() }
        }
        .onChange(of: game.phase) { _, phase in
            if phase == .won { celebrate() }
        }
        .task {
            while !Task.isCancelled {
                game.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        // The paywall sheet is rooted on the NavigationStack, so setting its
        // context while the win card is up presents nothing. Dismiss the win
        // card first and hand off on the way out.
        .sheet(isPresented: $showWinCard, onDismiss: {
            if let feature = pendingPaywall {
                pendingPaywall = nil
                paywall.present(feature)
            }
        }) {
            WinView(game: game, solve: solve ?? SolveResult(counted: true, newBestTime: false),
                    onUnlock: offersUnlock ? {
                        pendingPaywall = .largeBoards
                        showWinCard = false
                    } : nil)
                // Expandable: at accessibility sizes the recap and the Done
                // button fell below a fixed half sheet with no way to scroll.
                .mediumSheet(expandable: true)
        }
    }

    private var board: some View {
        BoardView(
            game: game,
            rippleDistances: rippleDistances,
            highlightedIslands: Set(hint?.highlightIslands ?? []),
            highlightedEdges: Set(hint?.highlightEdges ?? []),
            warningIslands: warningIslands,
            claimsFocus: true,
            onTapIsland: { game.tapIsland($0) },
            onCycleEdge: { cycle($0) }
        )
        #if os(tvOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        .frame(maxWidth: boardSide, maxHeight: boardSide)
        .padding(.horizontal, 8)
        #endif
    }

    private func hintBanner(_ hint: Hint) -> some View {
        HintBanner(
            hint: hint,
            onMore: {
                withAnimation(Motion.overlay) {
                    self.hint = hintEngine.escalate(hint, for: game, mastery: mastery,
                                                    policy: hintPolicy)
                }
            },
            onApply: hint.level == .resolution && !hint.isErrorHint ? {
                game.apply(hint.application)
                withAnimation(Motion.overlay) { self.hint = nil }
            } : nil,
            onDismiss: {
                withAnimation(Motion.overlay) { self.hint = nil }
            },
            onUnlock: { paywall.present(.teachingHints) },
            puzzle: game.puzzle
        )
    }

    #if os(tvOS)
    /// The column beside the board: clock, size, Hint and Undo, and how the
    /// remote plays.
    private var remoteSidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(TimeFormatting.clock(game.elapsed))
                .numberFont(Metrics.headerNumber)
                .foregroundStyle(Theme.inkSoft)
                .accessibilityLabel("Time \(TimeFormatting.spoken(game.elapsed))")
            Text("\(boardSize.label) · \(game.difficultyForRecords.label)")
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
            if let hint {
                // In the column, not under the board: the board has the
                // full height on a television.
                hintBanner(hint)
            }
            remoteControls
            Spacer()
            remoteGuide
        }
        .frame(width: 480, alignment: .leading)
        // Any press left off the board lands here, whatever its height.
        .focusSection()
    }

    /// How the remote plays.
    private var remoteGuide: some View {
        Text(game.selected == nil
             ? "Select picks up an island.\nMenu goes back."
             : "Press a direction to draw a bridge, again for a double.\nSelect or Menu puts it down.")
            .font(.title3)
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .animation(nil, value: game.selected)
    }

    /// Hint and Undo in the content, not the toolbar: on tvOS a toolbar is
    /// its own focus container that focus can climb into and not come back
    /// from (Just Kakuro). Off while an island is picked up, so an arrow can
    /// only ever draw a bridge.
    private var remoteControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { requestHint() } label: {
                Label("Hint", systemImage: "lightbulb")
            }
            .disabled(game.phase != .playing)
            Button { undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!game.canUndo || game.phase != .playing)
        }
        .disabled(game.selected != nil)
    }
    #endif

    private var header: some View {
        HStack {
            Text(TimeFormatting.clock(game.elapsed))
                .numberFont(Metrics.headerNumber)
                .foregroundStyle(Theme.inkSoft)
                .accessibilityLabel("Time \(TimeFormatting.spoken(game.elapsed))")
            Spacer()
            // Size first, then difficulty — the same order the Daily card and
            // Stats use. Difficulty is the *requested* band, matching records.
            Text("\(boardSize.label) · \(game.difficultyForRecords.label)")
                .font(Metrics.largeHeader ? .title3.weight(.medium) : .footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// The board's size band, derived from its grid — a puzzle carries its
    /// geometry, not a size tag.
    private var boardSize: BoardSize {
        switch game.puzzle.rows {
        case ...7: .small
        case ...10: .medium
        default: .large
        }
    }

    private func requestHint() {
        withAnimation(Motion.overlay) {
            hint = hintEngine.hint(for: game, mastery: mastery,
                                   showErrors: progress.settings.showErrors,
                                   policy: hintPolicy)
        }
    }

    private func undo() {
        game.undo()
        persist()
    }

    private func cycle(_ edge: Int) {
        let hadHint = hint != nil
        let outcome = game.cycleBridge(edge: edge)
        switch outcome {
        case .drewSingle: Haptics.bridge()
        case .drewDouble: Haptics.bridgeDouble()
        case .cleared: Haptics.clear()
        case .blocked: Haptics.error()
        }
        if outcome != .blocked,
           game.isSatisfied(game.puzzle.edges[edge].a) || game.isSatisfied(game.puzzle.edges[edge].b) {
            Haptics.islandComplete()
        }
        // Mastery: an unaided draw that matches the solver's next deduction
        // chain credits the chain's hardest technique — once per corridor per
        // game (the claim guard stops place/undo/replace farming). A visible
        // hint at any level makes the move aided.
        if outcome == .drewSingle || outcome == .drewDouble,
           !hadHint, game.claimMasteryCredit(edge: edge) {
            mastery.recordBridge(edge: edge, game: game, unaided: true)
        }
    }

    private func updateWarnings() {
        let component = game.satisfiedIsolatedComponent()
        withAnimation(Motion.selection) {
            warningIslands = component.map(Set.init) ?? []
        }
    }

    private func persist() {
        guard game.phase != .won else { return }
        // A board left without a move is not worth a save, and saving it would
        // overwrite the game Continue points at: Play, look, back out, and the
        // half-finished puzzle was gone. The same board as the saved one still
        // writes, so undoing back to empty is kept. Each game writes only its
        // own slot: a Daily never replaces the standard game, nor the reverse.
        let sameBoard = progress.savedGame(game.slot)?.generated == game.generated
        progress.saveGame(game.snapshot, hasProgress: game.hasMoves || sameBoard)
    }

    /// The win: ripple sweeps the network from the last bridge, then the card.
    private func celebrate() {
        progress.clearSavedGame(game.slot)
        let time = game.elapsed
        // A Daily opened again from the archive is a replay: it keeps its first
        // time and must not count as another solve or set a best time it never
        // earned. `recordWin` decides, from PuzzleKit's DailyRecord.
        let result = progress.recordWin(size: boardSize, difficulty: game.difficultyForRecords,
                                        time: time, daily: game.dailyKey)
        solve = result
        Haptics.win()
        let spoken = "Solved in \(TimeFormatting.spoken(time))" + (result.newBestTime ? ", a new best time." : ".")
        Task {
            // After the win card takes focus, or its arrival cuts this off.
            try? await Task.sleep(for: .seconds(1.2))
            BoardSpeech.announce(spoken)
        }
        let origin = game.lastMoveIsland ?? 0
        let distances = game.rippleDistances(from: origin)
        rippleDistances = distances
        for hop in 0..<min(3, (distances.values.max() ?? 0) + 1) {
            let delay = Double(hop) * Motion.rippleStagger
            Task {
                try? await Task.sleep(for: .seconds(delay))
                Haptics.ripple()
            }
        }
        let totalHops = Double(distances.values.max() ?? 0)
        let rippleTime = reduceMotion ? 0.2 : totalHops * Motion.rippleStagger + 0.55
        Task {
            try? await Task.sleep(for: .seconds(rippleTime))
            showWinCard = true
        }
    }
}
