import CoreGraphics
import MullionCore
import Testing
@testable import Mullion

@MainActor
struct DragSnapControllerTests {
    private func makeController(_ screens: [ScreenGeometry] = [FakeScreens.laptop]) -> DragSnapController {
        DragSnapController(screens: FakeScreens(screens: screens), settings: { .defaults })
    }

    @Test func followsTheCursorIntoAnArea() {
        let controller = makeController()
        controller.dragStarted(at: CGPoint(x: 700, y: 400))
        #expect(controller.match == nil)
        controller.dragMoved(to: CGPoint(x: 1, y: 400))
        #expect(controller.match?.action == .leftHalf)
    }

    @Test func endingReturnsTheAreaAndForgetsIt() {
        let controller = makeController()
        controller.dragStarted(at: CGPoint(x: 700, y: 400))
        let ended = controller.dragEnded(at: CGPoint(x: 1469, y: 400))
        #expect(ended?.action == .rightHalf)
        #expect(controller.match == nil)
    }

    @Test func endingOutsideEveryAreaReturnsNothing() {
        let controller = makeController()
        controller.dragStarted(at: CGPoint(x: 1, y: 400))
        #expect(controller.dragEnded(at: CGPoint(x: 700, y: 400)) == nil)
    }

    @Test(arguments: [FakeScreens.externalRight, FakeScreens.externalAbove, FakeScreens.portraitLeft])
    func snapsOnEveryConnectedScreen(other: ScreenGeometry) {
        let controller = makeController([FakeScreens.laptop, other])
        controller.dragStarted(at: CGPoint(x: 700, y: 400))
        controller.dragMoved(to: CGPoint(x: other.frame.minX + 1, y: other.frame.midY))
        #expect(controller.match?.action == .leftHalf)
        #expect(controller.match?.screen.id == other.id)
    }

    @Test func cancellingForgetsTheArea() {
        let controller = makeController()
        controller.dragStarted(at: CGPoint(x: 1, y: 400))
        controller.dragCancelled()
        #expect(controller.match == nil)
    }
}
