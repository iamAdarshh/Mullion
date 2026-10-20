import CoreGraphics
import Testing
@testable import MullionCore

struct DragAwayPlannerTests {
    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)
    private static let snappedLeft = SnapRecord(action: .leftHalf, halfFraction: nil, frame: leftHalf)
    /// Where the window was before Mullion first snapped it.
    private static let original = CGRect(x: 200, y: 200, width: 600, height: 400)

    private func plan(
        droppedAt dropped: CGRect,
        cursor: CGPoint,
        frameBeforeDrag: CGRect = leftHalf,
        lastSnap: SnapRecord? = snappedLeft,
        restoreFrame: CGRect? = original,
        screens: [ScreenGeometry] = [Screens.macBookAir13]
    ) -> ActionPlan? {
        DragAwayPlanner.plan(
            for: WindowContext(frame: dropped, lastSnap: lastSnap, restoreFrame: restoreFrame),
            frameBeforeDrag: frameBeforeDrag,
            cursor: cursor,
            screens: screens
        )
    }

    // MARK: When

    @Test func aSnappedWindowDraggedAwayGetsItsSizeBackUnderTheCursor() {
        // Grabbed 20 % across the title bar: the cursor stays 20 % across the restored window.
        let result = plan(droppedAt: CGRect(x: 300, y: 100, width: 735, height: 919), cursor: CGPoint(x: 447, y: 110))
        #expect(result?.target == CGRect(x: 327, y: 100, width: 600, height: 400))
        #expect(result?.screen.id == "macBookAir13")
        #expect(result?.record == nil)
    }

    @Test func aWindowMullionNeverSnappedIsLeftAlone() {
        let result = plan(
            droppedAt: CGRect(x: 300, y: 100, width: 735, height: 919),
            cursor: CGPoint(x: 447, y: 110),
            lastSnap: nil,
            restoreFrame: nil
        )
        #expect(result == nil)
    }

    @Test func withoutARestoreFrameNothingHappens() {
        let result = plan(
            droppedAt: CGRect(x: 300, y: 100, width: 735, height: 919),
            cursor: CGPoint(x: 447, y: 110),
            restoreFrame: nil
        )
        #expect(result == nil)
    }

    /// The user had already moved or resized the snapped window: it isn't snapped any more.
    @Test func aDragThatStartsAwayFromTheSnappedFrameIsLeftAlone() {
        let result = plan(
            droppedAt: CGRect(x: 300, y: 100, width: 735, height: 919),
            cursor: CGPoint(x: 447, y: 110),
            frameBeforeDrag: Self.leftHalf.offsetBy(dx: 40, dy: 0)
        )
        #expect(result == nil)
    }

    @Test func aWindowDroppedBackWhereItWasStaysSnapped() {
        let result = plan(droppedAt: Self.leftHalf.offsetBy(dx: 1, dy: 2), cursor: CGPoint(x: 148, y: 49))
        #expect(result == nil)
    }

    @Test func aSmallDragAwayStillCounts() {
        let result = plan(droppedAt: Self.leftHalf.offsetBy(dx: 3, dy: 0), cursor: CGPoint(x: 150, y: 47))
        #expect(result?.target.size == Self.original.size)
    }

    // MARK: Where

    @Test func theRestoredWindowStaysOnScreen() {
        // Grabbed 90 % across, dropped near the right edge and partly under the menu bar.
        let result = plan(droppedAt: CGRect(x: 800, y: 10, width: 735, height: 919), cursor: CGPoint(x: 1461.5, y: 20))
        #expect(result?.target == CGRect(x: 870, y: 37, width: 600, height: 400))
    }

    @Test func aRestoredWindowLargerThanTheScreenIsShrunkToFit() {
        let result = plan(
            droppedAt: CGRect(x: 300, y: 100, width: 735, height: 919),
            cursor: CGPoint(x: 447, y: 110),
            restoreFrame: CGRect(x: 0, y: 0, width: 2000, height: 1200)
        )
        #expect(result?.target == CGRect(x: 0, y: 37, width: 1470, height: 919))
    }

    @Test func itLandsOnTheDisplayUnderTheCursor() {
        let result = plan(
            droppedAt: CGRect(x: 1853, y: -10, width: 735, height: 919),
            cursor: CGPoint(x: 2000, y: 0),
            screens: Screens.laptopLeftOfExternal
        )
        #expect(result?.screen.id == "studioRight")
        #expect(result?.target == CGRect(x: 1880, y: -10, width: 600, height: 400))
    }

    @Test(arguments: Screens.all)
    func droppedInTheMiddleItKeepsItsSizeInsideTheVisibleFrame(screen: ScreenGeometry) {
        let visible = screen.visibleFrame
        let dropped = CGRect(x: visible.midX - 300, y: visible.midY - 200, width: 735, height: 400)
        let result = DragAwayPlanner.plan(
            for: WindowContext(frame: dropped, lastSnap: Self.snappedLeft, restoreFrame: Self.original),
            frameBeforeDrag: Self.leftHalf,
            cursor: CGPoint(x: dropped.minX + 100, y: dropped.minY + 10),
            screens: [screen]
        )
        #expect(result?.target.size == Self.original.size)
        #expect(result.map { visible.contains($0.target) } == true)
    }
}
