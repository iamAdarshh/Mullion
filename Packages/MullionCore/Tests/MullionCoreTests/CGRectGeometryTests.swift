import CoreGraphics
import Testing
@testable import MullionCore

struct CGRectGeometryTests {
    @Test func roundingRoundsEdgesSoNeighboursStillTouch() {
        // Thirds of 2560 pt: 853.33…, 1706.66…
        let first = CGRect(x: 0, y: 25, width: 2560.0 / 3, height: 1415).roundedToEdges()
        let center = CGRect(x: 2560.0 / 3, y: 25, width: 2560.0 / 3, height: 1415).roundedToEdges()

        #expect(first == CGRect(x: 0, y: 25, width: 853, height: 1415))
        #expect(center == CGRect(x: 853, y: 25, width: 854, height: 1415))
        #expect(first.maxX == center.minX)
    }

    @Test func clampedMovesARectInside() {
        let bounds = CGRect(x: 0, y: 37, width: 1470, height: 919)
        let rect = CGRect(x: 1300, y: 900, width: 400, height: 300)
        #expect(rect.clamped(to: bounds) == CGRect(x: 1070, y: 656, width: 400, height: 300))
    }

    @Test func clampedShrinksARectThatIsTooBig() {
        let bounds = CGRect(x: 0, y: 37, width: 1470, height: 919)
        let rect = CGRect(x: -50, y: 0, width: 2000, height: 500)
        #expect(rect.clamped(to: bounds) == CGRect(x: 0, y: 37, width: 1470, height: 500))
    }

    @Test func movedInsideNeverShrinks() {
        let bounds = CGRect(x: 0, y: 37, width: 1470, height: 919)
        let tooWide = CGRect(x: 100, y: 100, width: 1600, height: 300)
        #expect(tooWide.movedInside(bounds) == CGRect(x: 0, y: 100, width: 1600, height: 300))
    }

    private static let approximateEqualityCases: [(CGRect, Bool)] = [
        (CGRect(x: 0, y: 0, width: 100, height: 100), true),
        (CGRect(x: 1.9, y: -1.9, width: 101.9, height: 98.1), true),
        (CGRect(x: 2.1, y: 0, width: 100, height: 100), false),
        (CGRect(x: 0, y: 0, width: 100, height: 97.5), false),
    ]

    @Test(arguments: approximateEqualityCases)
    func approximateEquality(rect: CGRect, isEqual: Bool) {
        #expect(rect.isApproximatelyEqual(to: CGRect(x: 0, y: 0, width: 100, height: 100), tolerance: 2) == isEqual)
    }
}
