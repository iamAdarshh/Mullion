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

    /// A window on a 1470 × 919 screen that behaves like the one in #16: a resize is cut short at the
    /// screen's right and bottom edges, and `droppedResizes` resizes right after a move are ignored.
    private final class SimulatedWindow: FrameWriting {
        private static let screen = CGRect(x: 0, y: 37, width: 1470, height: 919)

        var current: CGRect
        var minimumSize = CGSize.zero
        var droppedResizes = 0
        /// Writes from this index on time out.
        var failingFromWrite = Int.max
        private(set) var writes: [String] = []
        private var justMoved = false

        init(frame: CGRect) {
            current = frame
        }

        func setSize(_ size: CGSize) throws {
            try record("size")
            defer { justMoved = false }
            if justMoved, droppedResizes > 0 {
                droppedResizes -= 1
                return
            }
            current.size = CGSize(
                width: max(min(size.width, Self.screen.maxX - current.minX), minimumSize.width),
                height: max(min(size.height, Self.screen.maxY - current.minY), minimumSize.height)
            )
        }

        func setPosition(_ origin: CGPoint) throws {
            try record("position")
            current.origin = origin
            justMoved = true
        }

        func frame() throws -> CGRect {
            current
        }

        private func record(_ write: String) throws {
            guard writes.count < failingFromWrite else { throw AXWindowError.appNotResponding }
            writes.append(write)
        }
    }

    private static let rightHalf = CGRect(x: 735, y: 37, width: 735, height: 919)
    private static let topHalf = CGRect(x: 0, y: 37, width: 1470, height: 460)

    /// Regression (#16): the first resize stopped at the right edge and the final one was dropped,
    /// which left the window at 735 × 460 in the top-left corner.
    @Test func aResizeCutShortAndDroppedIsAskedForAgain() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.droppedResizes = 1

        try AXWindow.write(Self.topHalf, order: .sizeFirst, resizable: true, to: window)

        #expect(window.writes == ["size", "position", "size", "position", "size"])
        #expect(window.current == Self.topHalf)
    }

    @Test func movingFirstIsNotCutShort() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)

        try AXWindow.write(Self.topHalf, order: .positionFirst, resizable: true, to: window)

        #expect(window.writes == ["position", "size"])
        #expect(window.current == Self.topHalf)
    }

    @Test func aWindowThatStaysSmallIsAskedOnlyOnce() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.droppedResizes = 5

        try AXWindow.write(Self.topHalf, order: .positionFirst, resizable: true, to: window)

        #expect(window.writes == ["position", "size", "position", "size"])
        #expect(window.current == CGRect(x: 0, y: 37, width: 735, height: 919))
    }

    /// AC-2: the dispatcher re-anchors a window with a minimum size; asking again can't help it.
    @Test func aMinimumSizeIsNotAskedForAgain() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.minimumSize = CGSize(width: 800, height: 0)

        try AXWindow.write(Self.topHalf, order: .positionFirst, resizable: true, to: window)

        #expect(window.writes == ["position", "size"])
    }

    @Test func aFixedSizeWindowIsOnlyMoved() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)

        try AXWindow.write(Self.topHalf, order: .sizeFirst, resizable: false, to: window)

        #expect(window.writes == ["position"])
    }

    /// The window already moved, so a timeout on the second try mustn't fail the snap.
    @Test func aFailedSecondTryKeepsTheMove() throws {
        let window = SimulatedWindow(frame: Self.rightHalf)
        window.droppedResizes = 1
        window.failingFromWrite = 2

        try AXWindow.write(Self.topHalf, order: .positionFirst, resizable: true, to: window)

        #expect(window.current == CGRect(x: 0, y: 37, width: 735, height: 919))
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
