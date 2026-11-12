import SwiftUI

struct ContentView: View {
    @Environment(PaywallPresenter.self) private var paywall
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .tint(Theme.bridge)
        #if DEBUG
        // `-HashiOpenGame` opens straight onto a small easy board, for
        // screenshots and for platforms where a harness cannot click (the
        // Mac without Accessibility access). DEBUG only, string included.
        // `-HashiOpen medium|learn|lesson|drill` opens other screens the same
        // way, for the store screenshots on every platform.
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            guard path.isEmpty else { return }
            if arguments.contains("-HashiOpenGame") {
                path = [.game(size: .small, difficulty: .easy)]
            } else if let flag = arguments.firstIndex(of: "-HashiOpen"),
                      arguments.indices.contains(flag + 1) {
                switch arguments[flag + 1] {
                case "medium": path = [.game(size: .medium, difficulty: .medium)]
                case "learn": path = [.learn]
                case "lesson": path = [.learn, .tutorial(.fullIsland)]
                case "drill": path = [.practiceMenu, .practice(.onlyNeighbor)]
                default: break
                }
            }
        }
        #endif
        // One paywall for the whole app, rooted above the NavigationStack so it
        // presents identically from Home and from any pushed destination. The
        // binding is manual because `context` is private(set): the getter reads
        // it, and the setter only has to handle swipe-to-dismiss.
        .sheet(item: Binding(get: { paywall.context },
                             set: { if $0 == nil { paywall.dismiss() } })) { context in
            PaywallView(context: context)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .game(let size, let difficulty):
            GameLoaderView(key: .standard(size, difficulty),
                           requestedDifficulty: difficulty, dailyKey: nil)
        case .daily(let day):
            GameLoaderView(key: .daily(day),
                           requestedDifficulty: DailySeed.spec(for: day).difficulty,
                           dailyKey: day)
        case .dailyArchive:
            DailyArchiveView(path: $path)
        case .resume(let slot):
            ResumeGameView(slot: slot)
        case .tutorial(let technique):
            TutorialView(technique: technique)
        case .practice(let technique):
            PracticeView(technique: technique)
        case .learn:
            LearnMenuView(path: $path)
        case .practiceMenu:
            PracticeMenuView(path: $path)
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}

/// Waits for the puzzle cache (usually instant), then hosts the game.
struct GameLoaderView: View {
    let key: PuzzleCache.CacheKey
    let requestedDifficulty: Difficulty?
    let dailyKey: DayKey?
    @Environment(PuzzleCache.self) private var cache
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss

    @State private var game: HashiGame?
    @State private var fraction: Double = 0
    @State private var startedAt = Date.now

    var body: some View {
        Group {
            if let game {
                GameHostView(game: game)
            } else {
                PuzzleLoadingView(fraction: fraction, startedAt: startedAt) { dismiss() }
            }
        }
        .task {
            guard game == nil else { return }
            // Recorded before the await so a player who backgrounds during a
            // slow build still has their choice remembered next launch. The
            // *requested* difficulty — generate returns nearest-band on budget
            // exhaustion, and persisting that would make the picker jump.
            if case let .standard(size, difficulty) = key {
                progress.recordLastPlayed(size: size, difficulty: difficulty)
            }

            // Obtained synchronously, before the first suspension, so no
            // progress is missed and the entry cannot be rebuilt underneath us.
            let request = cache.request(key)
            let watcher = Task { @MainActor in
                for await value in request.progress {
                    fraction = max(fraction, value)
                }
            }
            defer { watcher.cancel() }

            // nil means cancelled — this view is on its way out.
            guard let generated = await request.puzzle() else { return }
            game = HashiGame(puzzle: generated,
                             requestedDifficulty: requestedDifficulty,
                             dailyKey: dailyKey)
        }
    }
}

/// Resolves the saved game **once**, on entry.
///
/// Reading `progress.savedGame` directly in the navigation destination means
/// the destination re-evaluates whenever the store changes — and winning
/// clears the save, so the live game would be swapped out for `MissingSaveView`
/// mid-celebration. The game must outlive its own save. (Kakuro shipped that.)
struct ResumeGameView: View {
    let slot: GameSlot
    @Environment(ProgressStore.self) private var progress

    @State private var game: HashiGame?
    @State private var resolved = false

    var body: some View {
        ZStack {
            SeaBackground()
            if let game {
                GameHostView(game: game)
            } else if resolved {
                MissingSaveView()
            }
        }
        .onAppear {
            guard !resolved else { return }
            if let snapshot = progress.savedGame(slot) {
                game = HashiGame(snapshot: snapshot)
            }
            resolved = true
        }
    }
}

/// Owns the game instance for the screen's lifetime.
struct GameHostView: View {
    @State var game: HashiGame

    var body: some View {
        GameView(game: game)
    }
}

/// Reached when the save was gone by the time the screen opened (finished on
/// another path, or cleared). It used to be a sentence with no way out but
/// the back button.
struct MissingSaveView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("That game is finished. Start a new one from Home.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button("Back to Home") { dismiss() }
                .font(.headline)
                .tint(Theme.bridge)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environment(ProgressStore())
        .environment(PuzzleCache())
        .environment(MasteryTracker())
        .environment(EntitlementStore(source: PreviewEntitlementSource(owned: true)))
        .environment(PaywallPresenter())
        .environment(TodayClock())
}
