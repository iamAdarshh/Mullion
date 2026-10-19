import CoreGraphics
import Testing
@testable import MullionCore

struct UnitRectTests {
    @Test func fullCoversTheWholeFrame() {
        let frame = CGRect(x: -545, y: -1415, width: 2560, height: 1415)
        #expect(UnitRect.full.rect(in: frame) == frame)
    }

    @Test func fractionsAreMeasuredFromTheFrameOrigin() {
        let frame = CGRect(x: 1470, y: -457, width: 1080, height: 1895)
        let bottomRightQuarter = UnitRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        #expect(bottomRightQuarter.rect(in: frame) == CGRect(x: 2010, y: 490.5, width: 540, height: 947.5))
    }

    @Test(arguments: Screens.all)
    func everyRectStaysInsideItsFrame(screen: ScreenGeometry) {
        let rect = UnitRect(x: 1.0 / 3, y: 0.5, width: 2.0 / 3, height: 0.5).rect(in: screen.visibleFrame)
        #expect(screen.visibleFrame.insetBy(dx: -0.001, dy: -0.001).contains(rect))
    }
}
