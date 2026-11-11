import Foundation
import Observation

/// Why the paywall is on screen. A struct rather than using `PaidFeature`
/// directly, so a source screen or a promo code can be added later without
/// changing every call site.
struct PaywallContext: Identifiable, Equatable {
    /// The gate the player hit, or nil when they came from Settings and the
    /// paywall should lead with the whole game rather than one feature.
    let feature: PaidFeature?

    var id: String { feature?.rawValue ?? "all" }
}

/// Owns paywall presentation for the whole app. One sheet at the root beats
/// five copies scattered through the view tree, and gives one place to hang a
/// purchase celebration later. A service, like `PuzzleCache` — not a ViewModel.
@Observable @MainActor
final class PaywallPresenter {
    private(set) var context: PaywallContext?

    func present(_ feature: PaidFeature? = nil) {
        context = PaywallContext(feature: feature)
    }

    func dismiss() {
        context = nil
    }
}
