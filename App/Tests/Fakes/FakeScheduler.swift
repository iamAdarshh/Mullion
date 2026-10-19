import Foundation
@testable import Mullion

/// Records scheduled actions; tests call `fire()` instead of waiting for real time to pass.
@MainActor
final class FakeScheduler: RepeatingScheduler {
    final class Scheduled: ScheduledTask {
        let interval: TimeInterval
        let tolerance: TimeInterval
        let action: @MainActor @Sendable () -> Void
        private(set) var isCancelled = false

        init(interval: TimeInterval, tolerance: TimeInterval, action: @escaping @MainActor @Sendable () -> Void) {
            self.interval = interval
            self.tolerance = tolerance
            self.action = action
        }

        func cancel() {
            isCancelled = true
        }
    }

    private(set) var tasks: [Scheduled] = []

    var activeTasks: [Scheduled] {
        tasks.filter { !$0.isCancelled }
    }

    func schedule(
        every interval: TimeInterval,
        tolerance: TimeInterval,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any ScheduledTask {
        let task = Scheduled(interval: interval, tolerance: tolerance, action: action)
        tasks.append(task)
        return task
    }

    /// Runs every active task once, as if its interval had elapsed.
    func fire() {
        for task in activeTasks {
            task.action()
        }
    }
}
