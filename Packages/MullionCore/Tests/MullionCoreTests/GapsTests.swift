import CoreGraphics
import Testing
@testable import MullionCore

struct GapsTests {
    private let visible = Screens.macBookAir13.visibleFrame // (0, 37, 1470, 919)

    @Test func zeroGapChangesNothing() {
        let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)
        #expect(Gaps.apply(0, to: leftHalf, within: visible) == leftHalf)
    }

    @Test func screenEdgesGetTheFullGap() {
        #expect(Gaps.apply(10, to: visible, within: visible) == CGRect(x: 10, y: 47, width: 1450, height: 899))
    }

    @Test func sharedEdgesGetHalfTheGapSoNeighboursAreOneGapApart() {
        let left = Gaps.apply(10, to: CGRect(x: 0, y: 37, width: 735, height: 919), within: visible)
        let right = Gaps.apply(10, to: CGRect(x: 735, y: 37, width: 735, height: 919), within: visible)

        #expect(left == CGRect(x: 10, y: 47, width: 720, height: 899))
        #expect(right == CGRect(x: 740, y: 47, width: 720, height: 899))
        #expect(right.minX - left.maxX == 10)
    }

    @Test func quarterInTheMiddleOfANonPrimaryScreen() {
        let screen = Screens.externalAbovePrimary[1].visibleFrame // (-545, -1415, 2560, 1415)
        let topRight = CGRect(x: 735, y: -1415, width: 1280, height: 707.5)

        #expect(Gaps.apply(20, to: topRight, within: screen) == CGRect(
            x: 745, y: -1395, width: 1250, height: 677.5
        ))
    }
}
