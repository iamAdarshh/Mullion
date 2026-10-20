import CoreGraphics
import MullionCore
import Testing

struct ScreenGeometryTests {
    @Test(arguments: Screens.all)
    func theVisibleFrameStartsBelowTheMenuBarInLocalSpace(screen: ScreenGeometry) {
        let local = screen.localRect(screen.visibleFrame)
        #expect(local.origin == CGPoint(
            x: screen.visibleFrame.minX - screen.frame.minX,
            y: screen.visibleFrame.minY - screen.frame.minY
        ))
        #expect(local.size == screen.visibleFrame.size)
    }

    @Test(arguments: Screens.all)
    func theWholeScreenIsAtTheOrigin(screen: ScreenGeometry) {
        #expect(screen.localRect(screen.frame) == CGRect(origin: .zero, size: screen.frame.size))
    }

    @Test func aScreenAboveAndLeftOfThePrimaryOffsetsBothAxes() {
        let above = Screens.externalAbovePrimary[1]
        let rect = CGRect(x: -545, y: -1415, width: 1280, height: 1415)
        #expect(above.localRect(rect) == CGRect(x: 0, y: 25, width: 1280, height: 1415))
    }
}
