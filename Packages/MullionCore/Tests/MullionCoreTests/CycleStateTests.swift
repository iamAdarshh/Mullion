import CoreGraphics
import Testing
@testable import MullionCore

struct CycleStateTests {
    @Test func cyclesHalfToTwoThirdsToOneThirdAndBack() {
        let second = CycleState.next(after: nil)
        let third = CycleState.next(after: second)
        let fourth = CycleState.next(after: third)

        #expect(second == 2.0 / 3)
        #expect(third == 1.0 / 3)
        #expect(fourth == 0.5)
        #expect(CycleState.next(after: fourth) == 2.0 / 3)
    }

    @Test func unknownFractionRestartsTheCycle() {
        #expect(CycleState.next(after: 0.42) == 2.0 / 3)
    }
}
