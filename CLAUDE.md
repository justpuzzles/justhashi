# CLAUDE.md — Just Hashi

iPhone/iPad puzzle game (iOS 18+) teaching Hashiwokakero (Bridges), modeled on Good Sudoku. Sibling of `../kakuro` — same architecture, same invariants. Deep engineering notes: `docs/ENGINEERING.md` (and `../kakuro/docs/ENGINEERING.md` for the lessons this project inherits).

## Critical invariants

- **Never edit project.pbxproj to add files.** `objectVersion 77` + `PBXFileSystemSynchronizedRootGroup`: every `.swift` file under `Hashi/` and `HashiTests/` joins the build automatically.
- **`Hashi/Engine/` is pure**: no SwiftUI/UIKit imports, every type `nonisolated` + `Sendable`. It must compile as a CLI: `swiftc -O -o bench Hashi/Engine/*.swift "$(tools/puzzlekit-sources.sh)"/*.swift bench/main.swift` (bench output to stderr).
- **`Theme` and `Motion` are `nonisolated` — load-bearing.** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` project-wide; a `UIColor(dynamicProvider:)` closure that inherits MainActor traps off-main (`EXC_BREAKPOINT`, intermittent, shipped in kakuro once). Guarded by `ThemeIsolationTests`; do not "fix".
- **No ViewModels.** `@Observable` (never ObservableObject), `@Environment` for services, view state as enums, `.task(id:)` for async effects.
- Every shipped puzzle is unique-solution AND fully solvable by `LogicalSolver` — enforced inside `HashiGenerator.generate`, not by convention.
- **All paid-tier gating lives in `FeatureGate`**, as pure `nonisolated` functions taking `unlocked:` explicitly. Add a gate there and call it; never scatter `isUnlocked` checks through views.
- `EntitlementSource.isOwned` returns `Bool?` — `nil` means "couldn't determine" and **must never downgrade** a cached entitlement. The `Transaction.updates` listener starts in `EntitlementStore.init`, not a view's `.task`.
- Paywalled rows stay **tappable** (they present the paywall); only mastery-locked rows are `.disabled`.
- The Daily puzzle is exempt from the board-size gate — the weekend schedule is `.large` and the Daily is free. See `FeatureGate.isDailyAvailable`.
- `Technique` enum declaration order is the source of truth for the solver loop, difficulty weights, hint escalation, tutorial sequence, and practice menu.
- Persistence: save on board change + scene backgrounding + disappear (never phase-change-only); `savedGame(_:)` is observable state, not a defaults read in a view body.
- **PuzzleKit (since 1.2)** is a Swift package from github.com/justpuzzles/PuzzleKit, pinned to a revision in the project (`Package.resolved`); a plain clone builds. To work on the kit, drag a local `../PuzzleKit` into the project (Xcode overrides the remote one) or set `PUZZLEKIT=../PuzzleKit` for the engine build; bump the pinned revision when the kit changes. It owns `DayKey`/`DaySeed`, the streak record (`DailyRecord`, still under `hashi.daily.v1`), the two save slots (`SaveSlots`: standard keeps `hashi.saveGame.v1`, daily is `hashi.saveGame.daily.v1`), `TodayClock` and the share text. `App/PuzzleKitExports.swift` re-exports it; engine files import it behind `#if canImport(PuzzleKit)`. Never change the seed prefix, the hash or `isoString`.

- **Mac, Apple TV and Vision Pro (branch `multiplatform`, 2026-11-12).** One target, `SDKROOT = auto`, as in Kakuro. Designed per platform (apple-skills `macos` and `visionos`, Kakuro's tvOS lessons), not windowed iPad:
  - *Mac*: drag with the mouse as on iPad, hover rings the island under the pointer, and the keyboard plays (`BoardKeys.swift`: arrows move a cursor, Space/Return picks an island up, arrows then draw bridges, Esc puts it down). Keys come from an `NSEvent` monitor, never SwiftUI focus (a focus-based board drops every key). Menu bar: Undo Bridge ⌘Z, Game › Hint ⇧⌘H (⌘H is the system's Hide) via `GameCommands` + `focusedSceneValue`. Window 1100×820, min 720×600. Sandboxed (`Hashi-macOS.entitlements`).
  - *Apple TV*: islands are focus stops; Select picks one up and it becomes the only focus stop, so arrows draw bridges (`onMoveCommand`) and cannot walk off; Select/Menu put it down. Wide layout: board full height, clock/Hint/Undo/guide in a column (a toolbar is a focus trap on tvOS). No share sheet. Islands 0.42 of a pitch.
  - *Vision Pro*: the sea is translucent over the window's glass; every island and `.hashi` button has the system hover highlight and islands a ≥60pt target; window opens wide (1180×860); header type a size up.
  - Icons: `tools/icon/generate_platform_icons.py` (TV layers, Vision layers, Mac rounded tiles) from the iOS drawing. `-HashiOpenGame` (DEBUG) opens a small board, for platforms a harness cannot click.

## Build & test

```bash
xcodebuild -project Hashi.xcodeproj -scheme Hashi -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build
xcodebuild test -project Hashi.xcodeproj -scheme Hashi -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
# iPad
xcodebuild test -project Hashi.xcodeproj -scheme Hashi -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=18.5'
# Mac (unit tests; the UIKit-only files skip themselves)
xcodebuild test -project Hashi.xcodeproj -scheme Hashi -destination 'platform=macOS' -only-testing:HashiTests
# Apple TV / Vision Pro builds
xcodebuild -project Hashi.xcodeproj -scheme Hashi -destination 'generic/platform=tvOS Simulator' build
xcodebuild -project Hashi.xcodeproj -scheme Hashi -destination 'generic/platform=visionOS Simulator' build
```

Always pin `OS=` (this machine has 18.x and 26.x runtimes). If simulator cloning fails ("stuck in creation state"): `-destination 'id=<udid>' -parallel-testing-enabled NO`.

Fast engine iteration without the simulator:
```bash
swiftc -O -o bench Hashi/Engine/*.swift "$(tools/puzzlekit-sources.sh)"/*.swift bench/main.swift && ./bench
```

## Layout

- `Hashi/App/` — @main, ContentView, Route navigation, HomeView
- `Hashi/Engine/` — models, LogicalSolver (powers hints), BacktrackingSolver (uniqueness only), HashiGenerator, Difficulty, DailySeed
- `Hashi/Game/` — HashiGame (@Observable @MainActor), BoardView/BoardLayout/BridgeGesture, PuzzleCache
- `Hashi/Teaching/` — HintEngine (nudge → technique → highlight → resolution), tutorial DSL + baked lesson boards, practice drills, MasteryTracker
- `Hashi/Design/` — Theme ("ukiyo-e sea" palette), Motion (named tokens only — no inline animation values in views), Haptics
- `Hashi/Persistence/` — ProgressStore (UserDefaults + Codable, versioned keys `hashi.*.v1`, `init(userDefaults:)` test seam)
- `Hashi/Store/` — the one-time unlock. `FeatureGate` (all gating as pure functions, no StoreKit), `EntitlementStore` (@Observable, StoreKit behind an `EntitlementSource` seam), `PaywallPresenter` + `PaywallView` + `LockedFeatureView`/`LockedFeaturePanel`
- `StoreKit/Hashi.storekit`, `tools/icon/generate_appicon.py` — repo root, **outside `Hashi/`**, because the synchronized root group ships anything under it inside the app bundle

## Conventions

Swift 6, Swift Testing (`@Suite`/`@Test`/`#expect`) in `HashiTests` hosted by the app. `struct` over `class`, classes `final`, no force unwraps. Team `8H42EZRCCP`, bundle `de.kaikunze.hashi`, display name "Just Hashi".

## Shipping

`AppStore/SUBMISSION.md` is the submission runbook: ASC ids, what is already
done, what is left, and the traps specific to this record. Read it before any
release. Regenerate assets with `AppStore/capture_screenshots.py`,
`AppStore/iap/generate.py` and `tools/icon/generate_appicon.py`.
