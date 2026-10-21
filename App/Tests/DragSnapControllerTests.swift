import CoreGraphics
import MullionCore
import Testing
@testable import Mullion

@MainActor
struct DragSnapControllerTests {
    private static let pid: pid_t = 4242
    private static let window = CGRect(x: 300, y: 200, width: 600, height: 400)
    private static let middle = CGPoint(x: 700, y: 400)
    /// The laptop's visible frame is (0, 37, 1470, 919).
    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)

    @MainActor
    private struct Harness {
        let preview = FakePreview()
        let controller: DragSnapController
        /// How many times the cursor entered an area, for haptic feedback.
        let entered = Counter()

        init(
            _ screens: [ScreenGeometry] = [FakeScreens.laptop],
            actionSettings: ActionSettings = .defaults,
            ignoredPIDs: Set<pid_t> = [],
            snapping: Bool = true
        ) {
            controller = DragSnapController(
                screens: FakeScreens(screens: screens),
                preview: preview,
                dragSettings: { .defaults },
                actionSettings: { actionSettings },
                isIgnored: { ignoredPIDs.contains($0) },
                isSnappingEnabled: { snapping },
                enteredArea: { [entered] in entered.calls += 1 }
            )
        }

        func start(at cursor: CGPoint = DragSnapControllerTests.middle, pid: pid_t = DragSnapControllerTests.pid) {
            let window = DraggedWindow(id: 7, pid: pid, frameBeforeDrag: DragSnapControllerTests.window)
            controller.dragStarted(window, at: cursor)
        }
    }

    @Test func followsTheCursorIntoAnArea() {
        let harness = Harness()
        harness.start()
        #expect(harness.controller.match == nil)
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 400))
        #expect(harness.controller.match?.action == .leftHalf)
    }

    /// One haptic tap per area entered: not on every mouse move inside it, and not on leaving it.
    @Test func reportsEachAreaEnteredOnce() {
        let harness = Harness()
        harness.start()
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 400))
        harness.controller.dragMoved(to: CGPoint(x: 2, y: 420))
        #expect(harness.entered.calls == 1)
        harness.controller.dragMoved(to: Self.middle)
        #expect(harness.entered.calls == 1)
        harness.controller.dragMoved(to: CGPoint(x: 1469, y: 400))
        #expect(harness.entered.calls == 2)
    }

    /// Drag to snap off: no preview and no snap, but the drop is still free, so a snapped window
    /// dragged away gets its size back (PRD §6.3).
    @Test func snappingOffStillAllowsDragAwayRestore() {
        let harness = Harness(snapping: false)
        harness.start()
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 400))
        #expect(harness.controller.match == nil)
        #expect(harness.controller.dragEnded(at: CGPoint(x: 1, y: 400)) == .free)
        #expect(harness.preview.prepared.isEmpty)
        #expect(harness.preview.shown.isEmpty)
        #expect(harness.entered.calls == 0)
    }

    @Test func endingReturnsTheAreaAndForgetsIt() {
        let harness = Harness()
        harness.start()
        let ended = harness.controller.dragEnded(at: CGPoint(x: 1469, y: 400))
        #expect(ended == .snap(SnapMatch(area: .right, screen: FakeScreens.laptop)))
        #expect(harness.controller.match == nil)
    }

    @Test func endingOutsideEveryAreaIsAFreeDrop() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        #expect(harness.controller.dragEnded(at: Self.middle) == .free)
    }

    @Test func endingWithOptionHeldLeavesTheWindowAlone() {
        let harness = Harness()
        harness.start()
        harness.controller.setSnappingDisabled(true)
        #expect(harness.controller.dragEnded(at: Self.middle) == .leaveAlone)
    }

    @Test(arguments: [FakeScreens.externalRight, FakeScreens.externalAbove, FakeScreens.portraitLeft])
    func snapsOnEveryConnectedScreen(other: ScreenGeometry) {
        let harness = Harness([FakeScreens.laptop, other])
        harness.start()
        harness.controller.dragMoved(to: CGPoint(x: other.frame.minX + 1, y: other.frame.midY))
        #expect(harness.controller.match?.action == .leftHalf)
        #expect(harness.controller.match?.screen.id == other.id)
        #expect(harness.preview.shown.last?.screenID == other.id)
    }

    @Test func cancellingForgetsTheArea() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragCancelled()
        #expect(harness.controller.match == nil)
    }

    // MARK: Preview

    @Test func startingADragPreparesThePreviewOnEveryScreen() {
        let harness = Harness([FakeScreens.laptop, FakeScreens.externalAbove])
        harness.start()
        #expect(harness.preview.prepared == [["laptop", "externalAbove"]])
    }

    @Test func enteringAnAreaPreviewsTheSnappedFrame() {
        let harness = Harness()
        harness.start()
        #expect(harness.preview.shown.isEmpty)
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 400))
        #expect(harness.preview.visible == Self.leftHalf)
        #expect(harness.preview.shown.last?.screenID == "laptop")
    }

    @Test func thePreviewIncludesTheGap() {
        let harness = Harness(actionSettings: ActionSettings(gap: 10))
        harness.start(at: CGPoint(x: 1, y: 400))
        #expect(harness.preview.visible == CGRect(x: 10, y: 47, width: 720, height: 899))
    }

    @Test func movingWithinAnAreaDoesNotRedrawThePreview() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragMoved(to: CGPoint(x: 2, y: 500))
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 600))
        #expect(harness.preview.shown.count == 1)
    }

    @Test func movingToAnotherAreaMovesThePreview() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 1))
        #expect(harness.preview.visible == CGRect(x: 0, y: 37, width: 735, height: 460))
    }

    @Test func leavingEveryAreaHidesThePreview() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragMoved(to: Self.middle)
        #expect(harness.preview.visible == nil)
    }

    @Test func droppingHidesThePreview() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragEnded(at: CGPoint(x: 1, y: 400))
        #expect(harness.preview.visible == nil)
    }

    @Test func cancellingHidesThePreview() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragCancelled()
        #expect(harness.preview.visible == nil)
    }

    // MARK: ⌥ disables snapping

    @Test func holdingOptionHidesThePreviewAtOnce() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.setSnappingDisabled(true)
        #expect(harness.controller.match == nil)
        #expect(harness.preview.visible == nil)
    }

    @Test func withOptionHeldNoAreaIsEnteredAndTheDropDoesNothing() {
        let harness = Harness()
        harness.controller.setSnappingDisabled(true)
        harness.start()
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 400))
        #expect(harness.preview.shown.isEmpty)
        #expect(harness.controller.dragEnded(at: CGPoint(x: 1, y: 400)) == .leaveAlone)
    }

    @Test func releasingOptionBringsThePreviewBackWithoutMoving() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.setSnappingDisabled(true)
        harness.controller.setSnappingDisabled(false)
        #expect(harness.controller.match?.action == .leftHalf)
        #expect(harness.preview.visible == Self.leftHalf)
    }

    @Test func optionOutsideADragShowsNothing() {
        let harness = Harness()
        harness.controller.setSnappingDisabled(true)
        harness.controller.setSnappingDisabled(false)
        #expect(harness.preview.shown.isEmpty)
        #expect(harness.preview.hides == 0)
    }

    // MARK: Ignore list

    @Test func anIgnoredAppNeverSnaps() {
        let harness = Harness(ignoredPIDs: [Self.pid])
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 1))
        #expect(harness.preview.shown.isEmpty)
        #expect(harness.controller.dragEnded(at: CGPoint(x: 1, y: 1)) == .leaveAlone)
    }

    @Test func releasingOptionDoesNotSnapAnIgnoredApp() {
        let harness = Harness(ignoredPIDs: [Self.pid])
        harness.controller.setSnappingDisabled(true)
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.setSnappingDisabled(false)
        #expect(harness.controller.match == nil)
    }

    @Test func theNextDragOfAnotherAppSnapsAgain() {
        let harness = Harness(ignoredPIDs: [Self.pid])
        harness.start(at: CGPoint(x: 1, y: 400))
        harness.controller.dragEnded(at: CGPoint(x: 1, y: 400))
        harness.start(at: CGPoint(x: 1, y: 400), pid: Self.pid + 1)
        #expect(harness.controller.match?.action == .leftHalf)
    }
}

/// Counts calls from a closure.
private final class Counter {
    var calls = 0
}
