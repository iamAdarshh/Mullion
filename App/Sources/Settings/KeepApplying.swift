import Observation

/// Runs `apply` now, and again every time an observable value it read changes. For connecting
/// `Preferences` to AppKit objects, which can't observe it the way SwiftUI views do.
@MainActor
func keepApplying(_ apply: @escaping @MainActor @Sendable () -> Void) {
    withObservationTracking(apply) {
        // Called before the value changes, once per registration: re-run and re-register after it.
        Task { @MainActor in keepApplying(apply) }
    }
}
