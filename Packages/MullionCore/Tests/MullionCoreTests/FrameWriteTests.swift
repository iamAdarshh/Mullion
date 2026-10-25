import CoreGraphics
import Testing
@testable import MullionCore

struct FrameWriteTests {
    /// Halves, quarters and the full visible frame of `screen`: the frames windows move between.
    private static func tiles(of screen: ScreenGeometry) -> [CGRect] {
        let visible = screen.visibleFrame
        let (width, height) = (visible.width / 2, visible.height / 2)
        let (midX, midY) = (visible.minX + width, visible.minY + height)
        return [
            visible,
            CGRect(x: visible.minX, y: visible.minY, width: width, height: visible.height),
            CGRect(x: midX, y: visible.minY, width: width, height: visible.height),
            CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: height),
            CGRect(x: visible.minX, y: midY, width: visible.width, height: height),
            CGRect(x: visible.minX, y: visible.minY, width: width, height: height),
            CGRect(x: midX, y: visible.minY, width: width, height: height),
            CGRect(x: visible.minX, y: midY, width: width, height: height),
            CGRect(x: midX, y: midY, width: width, height: height),
        ]
    }

    // MARK: Size before the move

    /// Regression (#16): resizing first stretched a right-half window past the screen edge, where an
    /// app cut the resize short, then dropped the final one. No write may leave the visible frame.
    @Test(arguments: Screens.all)
    func betweenTilesNoWriteLeavesTheScreen(screen: ScreenGeometry) {
        let bounds = screen.visibleFrame.insetBy(dx: -0.5, dy: -0.5)
        for window in Self.tiles(of: screen) {
            for target in Self.tiles(of: screen) {
                let first = FrameWrite.sizeBeforeMove(moving: window, to: target, within: screen.visibleFrame)
                let size = first ?? window.size
                #expect(bounds.contains(CGRect(origin: window.origin, size: size)), "\(window) → \(target)")
                #expect(bounds.contains(CGRect(origin: target.origin, size: size)), "\(window) → \(target)")
            }
        }
    }

    @Test func rightHalfToTopHalfShrinksToTheTopRightQuarterFirst() {
        let rightHalf = CGRect(x: 735, y: 37, width: 735, height: 919)
        let topHalf = CGRect(x: 0, y: 37, width: 1470, height: 460)
        let first = FrameWrite.sizeBeforeMove(moving: rightHalf, to: topHalf, within: Screens.macBookAir13.visibleFrame)
        #expect(first == CGSize(width: 735, height: 460))
    }

    /// Tiles are rounded to whole points, so a window can end half a point past a fractional visible
    /// frame (980.5) and still count as on it.
    @Test func aTileRoundedPastAFractionalEdgeStillShrinksFirst() {
        let visible = CGRect(x: 0, y: 37.5, width: 1470, height: 943)
        let bottomHalf = CGRect(x: 0, y: 509, width: 1470, height: 471.5).roundedToEdges()
        let rightHalf = CGRect(x: 735, y: 37.5, width: 735, height: 943).roundedToEdges()

        let first = FrameWrite.sizeBeforeMove(moving: bottomHalf, to: rightHalf, within: visible)

        #expect(first == CGSize(width: 735, height: 472))
    }

    /// Restore or Grow across two displays: the size is written before and after the move.
    @Test func aTargetSpanningTwoDisplaysGetsItsSizeFirst() {
        let visible = Screens.macBookAir13.visibleFrame
        let window = CGRect(x: 800, y: 200, width: 600, height: 300)
        let spanning = CGRect(x: 1000, y: 170, width: 1100, height: 360)

        #expect(FrameWrite.sizeBeforeMove(moving: window, to: spanning, within: visible) == spanning.size)
    }

    /// A window already no bigger than the target only needs moving, then resizing.
    @Test func aSmallerWindowIsMovedFirst() {
        let floating = CGRect(x: 100, y: 200, width: 600, height: 300)
        let first = FrameWrite.sizeBeforeMove(
            moving: floating, to: Screens.macBookAir13.visibleFrame, within: Screens.macBookAir13.visibleFrame
        )
        #expect(first == nil)
    }

    /// macOS keeps a window's size within its current display, so a window from another one gets the
    /// target size first (size → position → size).
    @Test(arguments: Screens.arrangements.filter { $0.count > 1 })
    func aWindowFromAnotherDisplayGetsTheTargetSizeFirst(screens: [ScreenGeometry]) throws {
        let source = try #require(screens.last)
        let destination = try #require(screens.first)
        let window = source.visibleFrame.insetBy(dx: 100, dy: 100)
        let target = destination.visibleFrame

        let first = FrameWrite.sizeBeforeMove(moving: window, to: target, within: destination.visibleFrame)

        #expect(first == target.size)
    }

    // MARK: Cut short

    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)

    @Test(arguments: [CGSize(width: 367, height: 919), CGSize(width: 735, height: 400)])
    func aSmallerWindowWasCutShort(size: CGSize) {
        #expect(FrameWrite.wasCutShort(size, target: Self.leftHalf.size))
    }

    /// A minimum size makes a window larger, never smaller; 2 pt allows for rounding.
    @Test(arguments: [CGSize(width: 800, height: 919), CGSize(width: 734, height: 917), Self.leftHalf.size])
    func aLargerOrRoundedWindowWasNot(size: CGSize) {
        #expect(!FrameWrite.wasCutShort(size, target: Self.leftHalf.size))
    }
}
