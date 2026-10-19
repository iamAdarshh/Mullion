import Testing
@testable import Mullion

@MainActor
struct PermissionMonitorTests {
    /// A monitor wired to fakes the test can drive.
    @MainActor
    private struct Harness {
        let monitor: PermissionMonitor
        let checker: FakeTrustChecker
        let scheduler: FakeScheduler

        init(trusted: Bool) {
            checker = FakeTrustChecker(trusted: trusted)
            scheduler = FakeScheduler()
            monitor = PermissionMonitor(checker: checker, scheduler: scheduler)
        }
    }

    @Test(arguments: [true, false])
    func initialStateComesFromChecker(trusted: Bool) {
        let harness = Harness(trusted: trusted)
        let monitor = harness.monitor
        #expect(monitor.isTrusted == trusted)
    }

    @Test func refreshWithoutChangeDoesNotNotify() {
        let harness = Harness(trusted: true)
        let monitor = harness.monitor
        var changes: [Bool] = []
        monitor.onChange = { changes.append($0) }

        monitor.refresh()

        #expect(changes.isEmpty)
    }

    @Test func revocationAndRegrantNotifyOncePerChange() {
        let harness = Harness(trusted: true)
        let monitor = harness.monitor
        let checker = harness.checker
        var changes: [Bool] = []
        monitor.onChange = { changes.append($0) }

        checker.trusted = false
        monitor.refresh()
        monitor.refresh()
        checker.trusted = true
        monitor.refresh()

        #expect(changes == [false, true])
        #expect(monitor.isTrusted)
    }

    @Test(arguments: [
        (PermissionMonitor.PollRate.onboarding, 1.0),
        (PermissionMonitor.PollRate.background, 5.0),
    ])
    func pollingInterval(rate: PermissionMonitor.PollRate, seconds: Double) {
        let harness = Harness(trusted: false)
        let monitor = harness.monitor
        let scheduler = harness.scheduler

        monitor.startPolling(rate)

        #expect(scheduler.activeTasks.map(\.interval) == [seconds])
    }

    @Test func switchingRateCancelsThePreviousTimer() {
        let harness = Harness(trusted: false)
        let monitor = harness.monitor
        let scheduler = harness.scheduler

        monitor.startPolling(.onboarding)
        monitor.startPolling(.background)

        #expect(scheduler.tasks.count == 2)
        #expect(scheduler.activeTasks.map(\.interval) == [5])
    }

    @Test func stopPollingCancelsTheTimer() {
        let harness = Harness(trusted: false)
        let monitor = harness.monitor
        let scheduler = harness.scheduler

        monitor.startPolling(.background)
        monitor.stopPolling()

        #expect(scheduler.activeTasks.isEmpty)
    }

    @Test func timerTickDetectsGrant() {
        let harness = Harness(trusted: false)
        let monitor = harness.monitor
        let checker = harness.checker
        let scheduler = harness.scheduler
        var changes: [Bool] = []
        monitor.onChange = { changes.append($0) }
        monitor.startPolling(.onboarding)

        checker.trusted = true
        scheduler.fire()

        #expect(changes == [true])
    }

    @Test func promptIsShownOnlyOncePerLaunch() {
        let harness = Harness(trusted: false)
        let monitor = harness.monitor
        let checker = harness.checker

        let first = monitor.requestTrust()
        let second = monitor.requestTrust()

        #expect(first == .promptShown)
        #expect(second == .openSettings)
        #expect(checker.promptCount == 1)
    }

    @Test func requestingTrustWhenAlreadyTrustedDoesNothing() {
        let harness = Harness(trusted: true)
        let monitor = harness.monitor
        let checker = harness.checker

        #expect(monitor.requestTrust() == .alreadyTrusted)
        #expect(checker.promptCount == 0)
    }
}
