import Foundation

/// `RepeatingScheduler` backed by a `Timer` on the main run loop.
@MainActor
struct TimerScheduler: RepeatingScheduler {
    func schedule(
        every interval: TimeInterval,
        tolerance: TimeInterval,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> any ScheduledTask {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            // The timer is added to the main run loop below, so it always fires on the main thread.
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = tolerance
        // `.common` so the timer keeps firing while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        return TimerTask(timer: timer)
    }
}

private final class TimerTask: ScheduledTask {
    private let timer: Timer

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer.invalidate()
    }
}
