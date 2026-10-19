import Foundation

/// Runs an action repeatedly on the main actor. Abstracted so time-based logic is testable without sleeps.
@MainActor
protocol RepeatingScheduler {
    /// Schedules `action` every `interval` seconds. `tolerance` lets macOS coalesce wake-ups to save energy.
    func schedule(
        every interval: TimeInterval,
        tolerance: TimeInterval,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any ScheduledTask
}

/// A handle to a scheduled repeating action.
@MainActor
protocol ScheduledTask: AnyObject {
    func cancel()
}
