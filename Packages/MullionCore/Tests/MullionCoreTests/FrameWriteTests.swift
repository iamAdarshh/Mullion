import CoreGraphics
import Testing
@testable import MullionCore

struct FrameWriteTests {
    private static let visible = Screens.macBookAir13.visibleFrame
    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)
    private static let rightHalf = CGRect(x: 735, y: 37, width: 735, height: 919)
    private static let topHalf = CGRect(x: 0, y: 37, width: 1470, height: 460)
    private static let maximized = CGRect(x: 0, y: 37, width: 1470, height: 919)

    // MARK: Order

    /// Regression (#16): resizing first stretched the window past the right edge, an app cut the resize
    /// short there and then dropped the final one, leaving it half width in the top-left corner.
    @Test(arguments: [
        (rightHalf, topHalf),
        (rightHalf, maximized),
        (CGRect(x: 100, y: 200, width: 600, height: 300), leftHalf),
    ])
    func resizingInPlaceWouldOverflowSoTheWindowMovesFirst(window: CGRect, target: CGRect) {
        #expect(FrameWrite.order(moving: window, to: target, within: Self.visible) == .positionFirst)
    }

    @Test func movingFirstWouldOverflowSoTheWindowIsResizedFirst() {
        let bottomRight = CGRect(x: 735, y: 497, width: 735, height: 459)
        #expect(FrameWrite.order(moving: Self.maximized, to: bottomRight, within: Self.visible) == .sizeFirst)
    }

    /// Neither order overflows: keep size → position → size, as before #16.
    @Test(arguments: [(leftHalf, topHalf), (topHalf, maximized)])
    func whenNeitherOrderOverflowsTheWindowIsResizedFirst(window: CGRect, target: CGRect) {
        #expect(FrameWrite.order(moving: window, to: target, within: Self.visible) == .sizeFirst)
    }

    /// The size is set first on the old display, so the move isn't refused for a window too big for it.
    @Test func aWindowFromAnotherDisplayIsResizedFirst() {
        let onExternal = CGRect(x: 2000, y: 100, width: 1200, height: 800)
        #expect(FrameWrite.order(moving: onExternal, to: Self.topHalf, within: Self.visible) == .sizeFirst)
    }

    // MARK: Cut short

    @Test(arguments: [CGSize(width: 735, height: 460), CGSize(width: 1470, height: 400)])
    func aSmallerWindowWasCutShort(size: CGSize) {
        #expect(FrameWrite.wasCutShort(size, target: Self.topHalf.size))
    }

    /// A minimum size makes a window larger, never smaller; apps that round sizes stay within 2 pt.
    @Test(arguments: [CGSize(width: 800, height: 919), CGSize(width: 734, height: 917), Self.leftHalf.size])
    func aLargerOrRoundedWindowWasNot(size: CGSize) {
        #expect(!FrameWrite.wasCutShort(size, target: Self.leftHalf.size))
    }
}
