import Foundation

/// Tracks whether Mullion is trusted for Accessibility and reports changes (PRD §6.9).
///
/// macOS posts no public notification when trust changes, so this polls: once per second while
/// onboarding is visible, and every 5 seconds otherwise. Callers also call `refresh()` when the
/// menu opens or an action runs, so a revocation is noticed right away in those cases.
@MainActor
final class PermissionMonitor {
    enum PollRate: Sendable {
        /// While the welcome window is open (PRD §6.9.2).
        case onboarding
        /// The rest of the time, to notice a revocation (PRD §6.9.3).
        case background

        var interval: TimeInterval {
            switch self {
            case .onboarding: 1
            case .background: 5
            }
        }

        /// Lets macOS coalesce wake-ups so idle CPU stays near zero (NFR-2).
        var tolerance: TimeInterval {
            switch self {
            case .onboarding: 0.1
            case .background: 1
            }
        }
    }

    enum RequestOutcome: Equatable {
        case alreadyTrusted
        /// macOS showed its Accessibility prompt.
        case promptShown
        /// The prompt was already shown during this launch, so the caller should open System Settings.
        case openSettings
    }

    private(set) var isTrusted: Bool
    /// Called on the main actor whenever `isTrusted` changes.
    var onChange: ((Bool) -> Void)?

    private let checker: any AccessibilityTrustChecking
    private let scheduler: any RepeatingScheduler
    private var pollTask: (any ScheduledTask)?
    private var hasPrompted = false

    init(checker: any AccessibilityTrustChecking, scheduler: any RepeatingScheduler) {
        self.checker = checker
        self.scheduler = scheduler
        isTrusted = checker.isTrusted()
    }

    /// Starts polling at `rate`, replacing any earlier schedule.
    func startPolling(_ rate: PollRate) {
        pollTask?.cancel()
        pollTask = scheduler.schedule(every: rate.interval, tolerance: rate.tolerance) { [weak self] in
            self?.refresh()
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Re-reads the trust state and calls `onChange` if it changed.
    func refresh() {
        let trusted = checker.isTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        Log.ax.notice("Accessibility trust changed, trusted: \(trusted, privacy: .public)")
        onChange?(trusted)
    }

    /// Asks for access. macOS doesn't reliably show its prompt a second time, so only the
    /// first request in a launch prompts; later ones tell the caller to open System Settings.
    func requestTrust() -> RequestOutcome {
        guard !checker.isTrusted() else { return .alreadyTrusted }
        guard !hasPrompted else { return .openSettings }
        hasPrompted = true
        _ = checker.promptForTrust()
        return .promptShown
    }
}
