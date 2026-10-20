import CoreGraphics
import MullionCore
import Testing
@testable import Mullion

@MainActor
struct DragSnapControllerTests {
    private static let window = CGRect(x: 300, y: 200, width: 600, height: 400)
    private static let middle = CGPoint(x: 700, y: 400)
    /// The laptop's visible frame is (0, 37, 1470, 919).
    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)

    @MainActor
    private struct Harness {
        let preview = FakePreview()
        let controller: DragSnapController

        init(_ screens: [ScreenGeometry] = [FakeScreens.laptop], actionSettings: ActionSettings = .defaults) {
            controller = DragSnapController(
                screens: FakeScreens(screens: screens),
                preview: preview,
                dragSettings: { .defaults },
                actionSettings: { actionSettings }
            )
        }

        func start(at cursor: CGPoint = DragSnapControllerTests.middle) {
            controller.dragStarted(windowFrame: DragSnapControllerTests.window, at: cursor)
        }
    }

    @Test func followsTheCursorIntoAnArea() {
        let harness = Harness()
        harness.start()
        #expect(harness.controller.match == nil)
        harness.controller.dragMoved(to: CGPoint(x: 1, y: 400))
        #expect(harness.controller.match?.action == .leftHalf)
    }

    @Test func endingReturnsTheAreaAndForgetsIt() {
        let harness = Harness()
        harness.start()
        let ended = harness.controller.dragEnded(at: CGPoint(x: 1469, y: 400))
        #expect(ended?.action == .rightHalf)
        #expect(harness.controller.match == nil)
    }

    @Test func endingOutsideEveryAreaReturnsNothing() {
        let harness = Harness()
        harness.start(at: CGPoint(x: 1, y: 400))
        #expect(harness.controller.dragEnded(at: Self.middle) == nil)
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
}
