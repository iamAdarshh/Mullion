import ApplicationServices
import Testing
@testable import Mullion

struct AXWindowTests {
    @Test(arguments: [true, false])
    func aSuccessfulQueryIsTakenAtItsWord(settable: Bool) throws {
        #expect(try AXWindow.resizability(queryError: .success, settable: settable) == settable)
    }

    /// Regression: a timed-out query used to count as "resizable", so a frozen app got two more
    /// blocking size calls, and a window whose size can't be set was moved and then left halfway.
    @Test func aTimeoutAbortsTheMoveBeforeAnythingIsWritten() {
        #expect(throws: AXWindowError.appNotResponding) {
            try AXWindow.resizability(queryError: .cannotComplete, settable: true)
        }
    }

    @Test(arguments: [AXError.attributeUnsupported, .noValue, .failure, .illegalArgument])
    func anyOtherErrorMeansMoveOnly(error: AXError) throws {
        #expect(try AXWindow.resizability(queryError: error, settable: true) == false)
    }

    // MARK: Writing a frame

    /// A window on a 1470 × 919 screen that behaves the way #16 suggests: a resize is cut short at the
    /// screen's right and bottom edges, and with `dropsResizeAfterCutShort` the next resize is ignored.
    private final class SimulatedWindow: FrameWriting {
        private static let screen = CGRect(x: 0, y: 37, width: 1470, height: 919)

        var current: CGRect
        var minimumSize = CGSize.zero
        var maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        var dropsResizeAfterCutShort = false
        /// Writes from this index on time out.
        var failingFromWrite = Int.max
        private(set) var writes: [String] = []
        private var lastResizeWasCutShort = false

        init(frame: CGRect) {
            current = frame
        }

        func setSize(_ size: CGSize) throws {
            try record("size")
            if dropsResizeAfterCutShort, lastResizeWasCutShort {
                lastResizeWasCutShort = false
                return
            }
            let room = CGSize(width: Self.screen.maxX - current.minX, height: Self.screen.maxY - current.minY)
            current.size = CGSize(
                width: max(min(size.width, room.width, maximumSize.width), minimumSize.width),
                height: max(min(size.height, room.height, maximumSize.height), minimumSize.height)
            )
            lastResizeWasCutShort = size.width > room.width || size.height > room.height
        }

        func setPosition(_ origin: CGPoint) throws {
            try record("position")
            current.origin = origin
        }

        func size() throws -> CGSize {
            current.size
        }

        private func record(_ write: String) throws {
            guard writes.count < failingFromWrite else { throw AXWindowError.appNotResponding }
            writes.append(write)
        }
    }

    private static let rightHalf = CGRect(x: 735, y: 37, width: 735, height: 919)
    private static let topHalf = CGRect(x: 0, y: 37, width: 1470, height: 460)
    private static let topRightQuarter = CGSize(width: 735, height: 460)

    /// Regression (#16), with the target size written first as before: the first resize stopped at the
    /// right edge and the final one was dropped, so the size is asked for once more.
    @Test func aResizeCutShortAndDroppedIsAskedForAgain() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.dropsResizeAfterCutShort = true

        try AXWindow.write(Self.topHalf, sizeBeforeMove: Self.topHalf.size, resizable: true, to: window)

        #expect(window.writes == ["size", "position", "size", "size"])
        #expect(window.current == Self.topHalf)
    }

    /// The fix for #16: shrinking first means no resize is cut short, so none is dropped either.
    @Test func shrinkingFirstIsNotCutShort() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.dropsResizeAfterCutShort = true

        try AXWindow.write(Self.topHalf, sizeBeforeMove: Self.topRightQuarter, resizable: true, to: window)

        #expect(window.writes == ["size", "position", "size"])
        #expect(window.current == Self.topHalf)
    }

    @Test func aWindowThatStaysSmallIsAskedOnlyOnce() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.maximumSize = CGSize(width: 735, height: 919)

        try AXWindow.write(Self.topHalf, sizeBeforeMove: Self.topRightQuarter, resizable: true, to: window)

        #expect(window.writes == ["size", "position", "size", "size"])
        #expect(window.current == CGRect(origin: Self.topHalf.origin, size: Self.topRightQuarter))
    }

    /// AC-2: the dispatcher re-anchors a window with a minimum size; asking again can't help it.
    @Test func aMinimumSizeIsNotAskedForAgain() throws {
        let window = SimulatedWindow(frame: CGRect(x: 100, y: 200, width: 600, height: 300))
        window.minimumSize = CGSize(width: 800, height: 0)
        let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)

        try AXWindow.write(leftHalf, sizeBeforeMove: nil, resizable: true, to: window)

        #expect(window.writes == ["position", "size"])
        #expect(window.current.width == 800)
    }

    @Test func aFixedSizeWindowIsOnlyMoved() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)

        try AXWindow.write(Self.topHalf, sizeBeforeMove: Self.topRightQuarter, resizable: false, to: window)

        #expect(window.writes == ["position"])
    }

    /// The window already moved, so a timeout on the second try mustn't fail the snap.
    @Test func aFailedSecondTryKeepsTheMove() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.maximumSize = CGSize(width: 735, height: 919)
        window.failingFromWrite = 3

        try AXWindow.write(Self.topHalf, sizeBeforeMove: Self.topRightQuarter, resizable: true, to: window)

        #expect(window.current == CGRect(origin: Self.topHalf.origin, size: Self.topRightQuarter))
    }

    // MARK: Matching a dropped window

    private static let dropped = CGRect(x: 100, y: 100, width: 600, height: 400)

    @Test func aWindowTheAppNudgedIsTheDroppedWindow() {
        #expect(AXWindow.isNudged(Self.dropped.offsetBy(dx: 12, dy: -8), from: Self.dropped, tolerance: 2))
    }

    // Regression: any main window of the same size matched, wherever it was, so a ⌘-drag of a
    // background window could snap the main window instead.
    @Test func aWindowOfTheSameSizeElsewhereIsNot() {
        #expect(!AXWindow.isNudged(Self.dropped.offsetBy(dx: 700, dy: 0), from: Self.dropped, tolerance: 2))
        #expect(!AXWindow.isNudged(Self.dropped.offsetBy(dx: 25, dy: 25), from: Self.dropped, tolerance: 2))
    }

    @Test func aWindowOfAnotherSizeIsNot() {
        let resized = CGRect(x: 100, y: 100, width: 610, height: 400)
        #expect(!AXWindow.isNudged(resized, from: Self.dropped, tolerance: 2))
    }
}
