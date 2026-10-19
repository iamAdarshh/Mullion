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
}
