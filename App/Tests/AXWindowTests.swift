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
