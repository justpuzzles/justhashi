import SwiftUI

@main
struct HashiApp: App {
    @State private var progress: ProgressStore
    @State private var cache = PuzzleCache()
    @State private var mastery: MasteryTracker
    @State private var entitlements: EntitlementStore
    @State private var paywall = PaywallPresenter()
    /// Today's day key for every screen, kept current across midnight.
    @State private var clock = TodayClock()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // UI tests and accessibility audits start from a fresh install.
        // DEBUG only, string included.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetState"),
           let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        #endif
        let store = ProgressStore()
        _progress = State(initialValue: store)
        _mastery = State(initialValue: MasteryTracker(store: store))
        _entitlements = State(initialValue: Self.makeEntitlementStore())
    }

    /// Real StoreKit, except when capturing App Store screenshots of the paid
    /// tier, which cannot be reached in a simulator without a live purchase.
    ///
    /// Wrapped in `#if DEBUG` deliberately: a launch argument that grants the
    /// unlock must not exist in the binary that ships. `ReleaseBuildTests`
    /// checks the flag is read from inside the guard.
    private static func makeEntitlementStore() -> EntitlementStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.screenshotUnlockFlag) {
            return EntitlementStore(source: PreviewEntitlementSource(owned: true))
        }
        #endif
        return EntitlementStore()
    }

    /// Outside the `#if` on purpose — the test has to be able to name it.
    static let screenshotUnlockFlag = "-HashiScreenshotUnlock"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
                .environment(cache)
                .environment(mastery)
                .environment(entitlements)
                .environment(paywall)
                .environment(clock)
                .onAppear {
                    Haptics.enabled = progress.settings.hapticsEnabled
                }
        }
        // No day-change notification reaches a suspended app, so a phone
        // unlocked the next morning would still be on yesterday.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clock.refresh() }
        }
    }
}
