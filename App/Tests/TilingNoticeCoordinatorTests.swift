import Testing
@testable import Mullion

@MainActor
struct TilingNoticeCoordinatorTests {
    @MainActor
    private final class FakeNotice: TilingNoticePresenting {
        var shown: [SystemTilingCheck.Conflicts] = []
        var choice = TilingNoticeChoice.openSettings

        func present(_ conflicts: SystemTilingCheck.Conflicts, completion: @escaping (TilingNoticeChoice) -> Void) {
            shown.append(conflicts)
            completion(choice)
        }
    }

    @MainActor
    private final class State {
        var conflicts: SystemTilingCheck.Conflicts = [.edgeTiling]
        var isHidden = false
        var settingsOpened = 0
    }

    @MainActor
    private struct Harness {
        let notice = FakeNotice()
        let state = State()
        let coordinator: TilingNoticeCoordinator

        init() {
            let state = state
            coordinator = TilingNoticeCoordinator(
                conflicts: { state.conflicts },
                isHidden: { state.isHidden },
                hide: { state.isHidden = true },
                presenter: notice,
                openSettings: { state.settingsOpened += 1 }
            )
        }
    }

    @Test func showsTheConflictsThatAreOn() {
        let harness = Harness()
        harness.state.conflicts = [.edgeTiling, .optionTiling]
        harness.coordinator.showIfNeeded()
        #expect(harness.notice.shown == [[.edgeTiling, .optionTiling]])
    }

    @Test func showsOncePerLaunch() {
        let harness = Harness()
        harness.coordinator.showIfNeeded()
        harness.coordinator.showIfNeeded()
        #expect(harness.notice.shown.count == 1)
    }

    @Test func nothingToReportShowsNothing() {
        let harness = Harness()
        harness.state.conflicts = []
        harness.coordinator.showIfNeeded()
        #expect(harness.notice.shown.isEmpty)
    }

    /// Tiling turned off later in the launch, then back on: the first check found nothing, so it may still show.
    @Test func aCheckThatFoundNothingDoesNotUseUpTheLaunch() {
        let harness = Harness()
        harness.state.conflicts = []
        harness.coordinator.showIfNeeded()
        harness.state.conflicts = [.optionTiling]
        harness.coordinator.showIfNeeded()
        #expect(harness.notice.shown == [.optionTiling])
    }

    @Test func openSettingsOpensDesktopAndDock() {
        let harness = Harness()
        harness.coordinator.showIfNeeded()
        #expect(harness.state.settingsOpened == 1)
        #expect(!harness.state.isHidden)
    }

    @Test func dontShowAgainHidesItForGood() {
        let harness = Harness()
        harness.notice.choice = .dontShowAgain
        harness.coordinator.showIfNeeded()
        #expect(harness.state.isHidden)
        #expect(harness.state.settingsOpened == 0)
    }

    @Test func aHiddenNoticeIsNeverShown() {
        let harness = Harness()
        harness.state.isHidden = true
        harness.coordinator.showIfNeeded()
        #expect(harness.notice.shown.isEmpty)
    }
}
