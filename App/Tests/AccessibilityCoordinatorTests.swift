import Testing
@testable import Mullion

@MainActor
struct AccessibilityCoordinatorTests {
    /// Records what the coordinator asked its collaborators to do.
    @MainActor
    private final class Recorder {
        var windows: [FakeOnboarding] = []
        var settingsOpenCount = 0
        var trustChanges: [Bool] = []
    }

    /// A coordinator wired to fakes the test can drive.
    @MainActor
    private struct Harness {
        let checker: FakeTrustChecker
        let scheduler = FakeScheduler()
        let coordinator: AccessibilityCoordinator
        private let recorder = Recorder()

        var windows: [FakeOnboarding] {
            recorder.windows
        }

        var settingsOpenCount: Int {
            recorder.settingsOpenCount
        }

        var trustChanges: [Bool] {
            recorder.trustChanges
        }

        var activeIntervals: [Double] {
            scheduler.activeTasks.map(\.interval)
        }

        init(trusted: Bool) {
            let recorder = recorder
            checker = FakeTrustChecker(trusted: trusted)
            coordinator = AccessibilityCoordinator(
                checker: checker,
                scheduler: scheduler,
                makeOnboarding: { onRequestAccess in
                    let window = FakeOnboarding(onRequestAccess: onRequestAccess)
                    recorder.windows.append(window)
                    return window
                },
                openSettings: { recorder.settingsOpenCount += 1 }
            )
            coordinator.onTrustChange = { recorder.trustChanges.append($0) }
        }
    }

    @Test func startWhenTrustedPollsInTheBackgroundWithoutOnboarding() {
        let harness = Harness(trusted: true)

        harness.coordinator.start()

        #expect(harness.windows.isEmpty)
        #expect(harness.activeIntervals == [5])
    }

    @Test func startWhenUntrustedShowsOnboardingAndPollsEverySecond() {
        let harness = Harness(trusted: false)

        harness.coordinator.start()

        #expect(harness.windows.count == 1)
        #expect(harness.windows.first?.isOpen == true)
        #expect(harness.activeIntervals == [1])
    }

    @Test func grantClosesOnboardingAndFallsBackToBackgroundPolling() {
        let harness = Harness(trusted: false)
        harness.coordinator.start()

        harness.checker.trusted = true
        harness.scheduler.fire()

        #expect(harness.trustChanges == [true])
        #expect(harness.windows.first?.isOpen == false)
        #expect(harness.activeIntervals == [5])
    }

    @Test func closingOnboardingWithoutGrantFallsBackToBackgroundPolling() {
        let harness = Harness(trusted: false)
        harness.coordinator.start()

        harness.windows.first?.close()

        #expect(harness.trustChanges.isEmpty)
        #expect(harness.activeIntervals == [5])
    }

    @Test func revocationIsReportedAndOnboardingCanBeReopened() {
        let harness = Harness(trusted: true)
        harness.coordinator.start()

        harness.checker.trusted = false
        harness.coordinator.refresh()
        harness.coordinator.showOnboarding()

        #expect(harness.trustChanges == [false])
        #expect(harness.windows.count == 1)
        #expect(harness.activeIntervals == [1])
    }

    @Test func showingOnboardingTwiceReusesTheOpenWindow() {
        let harness = Harness(trusted: false)
        harness.coordinator.start()

        harness.coordinator.showOnboarding()

        #expect(harness.windows.count == 1)
        #expect(harness.windows.first?.presentCount == 2)
    }

    @Test func firstClickPromptsAndSecondClickOpensSettings() {
        let harness = Harness(trusted: false)
        harness.coordinator.start()
        let window = harness.windows.first

        window?.clickButton()
        #expect(harness.checker.promptCount == 1)
        #expect(harness.settingsOpenCount == 0)

        window?.clickButton()
        #expect(harness.checker.promptCount == 1)
        #expect(harness.settingsOpenCount == 1)
    }
}
