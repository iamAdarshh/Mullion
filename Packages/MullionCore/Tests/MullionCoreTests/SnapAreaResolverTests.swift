import CoreGraphics
import Testing
@testable import MullionCore

struct SnapAreaResolverTests {
    /// Points just inside each edge and corner of `screen`, with the action they snap to.
    static func edgePoints(of screen: ScreenGeometry) -> [(CGPoint, WindowAction)] {
        let frame = screen.frame
        let inset: CGFloat = 1
        return [
            (CGPoint(x: frame.minX + inset, y: frame.midY), .leftHalf),
            (CGPoint(x: frame.maxX - inset, y: frame.midY), .rightHalf),
            (CGPoint(x: frame.midX, y: frame.minY + inset), .maximize),
            (CGPoint(x: frame.minX + inset, y: frame.minY + inset), .topLeft),
            (CGPoint(x: frame.maxX - inset, y: frame.minY + inset), .topRight),
            (CGPoint(x: frame.minX + inset, y: frame.maxY - inset), .bottomLeft),
            (CGPoint(x: frame.maxX - inset, y: frame.maxY - inset), .bottomRight),
        ]
    }

    @Test(arguments: Screens.arrangements)
    func everyEdgeAndCornerSnapsOnEveryScreen(screens: [ScreenGeometry]) {
        for screen in screens {
            for (point, action) in Self.edgePoints(of: screen) {
                let match = SnapAreaResolver.resolve(cursor: point, screens: screens, previous: nil)
                #expect(match?.action == action, "\(screen.id) at \(point)")
                #expect(match?.screen.id == screen.id)
            }
        }
    }

    @Test(arguments: Screens.all)
    func theMiddleOfTheScreenIsNotAnArea(screen: ScreenGeometry) {
        let center = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        #expect(SnapAreaResolver.resolve(cursor: center, screens: [screen], previous: nil) == nil)
    }

    @Test func aCursorOutsideEveryScreenIsNotAnArea() {
        let point = CGPoint(x: 5000, y: 5000)
        #expect(SnapAreaResolver.resolve(cursor: point, screens: Screens.threeDisplays, previous: nil) == nil)
    }

    @Test func edgesStopAtTheConfiguredThickness() {
        let screen = Screens.macBookAir13
        let settings = DragSettings(edgeThickness: 5, cornerSize: 20)
        let inside = CGPoint(x: 4.5, y: 400)
        let outside = CGPoint(x: 5, y: 400)
        #expect(SnapAreaResolver.resolve(cursor: inside, screens: [screen], previous: nil, settings: settings)?
            .area == .left)
        #expect(SnapAreaResolver.resolve(cursor: outside, screens: [screen], previous: nil, settings: settings) == nil)
    }

    @Test func cornersReachAlongTheEdge() {
        let screen = Screens.macBookAir13
        #expect(resolve(CGPoint(x: 1, y: 19), on: [screen])?.area == .topLeft)
        #expect(resolve(CGPoint(x: 1, y: 20), on: [screen])?.area == .left)
        #expect(resolve(CGPoint(x: 1469, y: 940), on: [screen])?.area == .bottomRight)
    }

    // MARK: Shared edges between displays

    @Test func aSharedEdgeBelongsToTheScreenUnderTheCursor() {
        let screens = Screens.laptopLeftOfExternal
        #expect(resolve(CGPoint(x: 1469, y: 400), on: screens)?.area == .right)
        #expect(resolve(CGPoint(x: 1469, y: 400), on: screens)?.screen.id == "macBookAir13")
        #expect(resolve(CGPoint(x: 1470, y: 400), on: screens)?.area == .left)
        #expect(resolve(CGPoint(x: 1470, y: 400), on: screens)?.screen.id == "studioRight")
    }

    @Test func aDisplayAboveThePrimarySnapsAtItsBottomEdge() {
        let screens = Screens.externalAbovePrimary
        let match = resolve(CGPoint(x: 735, y: -1), on: screens)
        #expect(match?.screen.id == "studioAbove")
        #expect(match?.action == .centerThird)
        #expect(resolve(CGPoint(x: 735, y: 0), on: screens)?.action == .maximize)
    }

    // MARK: Hysteresis (AC-5)

    @Test func anAreaIsKeptUntilTheCursorIsEightPointsPastIt() {
        let screens = [Screens.macBookAir13]
        let left = resolve(CGPoint(x: 1, y: 400), on: screens)
        #expect(resolve(CGPoint(x: 12.5, y: 400), on: screens, previous: left)?.area == .left)
        #expect(resolve(CGPoint(x: 13, y: 400), on: screens, previous: left) == nil)
    }

    @Test func theCornerAndEdgeBoundaryDoesNotFlicker() {
        let screens = [Screens.macBookAir13]
        let corner = resolve(CGPoint(x: 1, y: 10), on: screens)
        #expect(corner?.area == .topLeft)
        // Just past the corner: still the corner, so a cursor wobbling on the line doesn't flicker.
        let wobble = resolve(CGPoint(x: 1, y: 22), on: screens, previous: corner)
        #expect(wobble?.area == .topLeft)
        let edge = resolve(CGPoint(x: 1, y: 28), on: screens, previous: wobble)
        #expect(edge?.area == .left)
        // And back again: the edge holds for 8 pt into the corner.
        #expect(resolve(CGPoint(x: 1, y: 13), on: screens, previous: edge)?.area == .left)
        #expect(resolve(CGPoint(x: 1, y: 11), on: screens, previous: edge)?.area == .topLeft)
    }

    @Test func hysteresisDoesNotCrossToAnotherScreen() {
        let screens = Screens.laptopLeftOfExternal
        let right = resolve(CGPoint(x: 1469, y: 400), on: screens)
        let next = resolve(CGPoint(x: 1471, y: 400), on: screens, previous: right)
        #expect(next?.screen.id == "studioRight")
        #expect(next?.area == .left)
    }

    // MARK: Bottom thirds

    @Test(arguments: [(200.0, WindowAction.firstThird), (735, .centerThird), (1270, .lastThird)])
    func theBottomEdgeIsSplitIntoThirds(x: CGFloat, action: WindowAction) {
        #expect(resolve(CGPoint(x: x, y: 955), on: [Screens.macBookAir13])?.action == action)
    }

    @Test func slidingIntoTheNextThirdGivesTwoThirds() {
        let screens = [Screens.macBookAir13]
        let first = resolve(CGPoint(x: 200, y: 955), on: screens)
        let slid = resolve(CGPoint(x: 600, y: 955), on: screens, previous: first)
        #expect(slid?.action == .firstTwoThirds)
        // Back into the starting third: a single third again.
        #expect(resolve(CGPoint(x: 200, y: 955), on: screens, previous: slid)?.action == .firstThird)
        // On into the far third: the two thirds the cursor is now sliding between.
        #expect(resolve(CGPoint(x: 1270, y: 955), on: screens, previous: slid)?.action == .lastTwoThirds)
    }

    @Test(arguments: [(200.0, WindowAction.firstTwoThirds), (1270, .lastTwoThirds)])
    func slidingOutOfTheCenterThirdGivesTwoThirds(x: CGFloat, action: WindowAction) {
        let screens = [Screens.macBookAir13]
        let center = resolve(CGPoint(x: 735, y: 955), on: screens)
        #expect(resolve(CGPoint(x: x, y: 955), on: screens, previous: center)?.action == action)
    }

    @Test func aBoundaryBetweenThirdsHasHysteresis() {
        let screens = [Screens.macBookAir13]
        let first = resolve(CGPoint(x: 400, y: 955), on: screens)
        #expect(resolve(CGPoint(x: 497, y: 955), on: screens, previous: first)?.action == .firstThird)
    }

    @Test func portraitScreensSnapTheBottomEdgeToTheBottomHalf() {
        let screen = Screens.portrait1080
        #expect(resolve(CGPoint(x: 540, y: 1919), on: [screen])?.action == .bottomHalf)
    }

    // MARK: Ultrawide

    @Test(arguments: [(600.0, WindowAction.topLeftSixth), (1720, .maximize), (2840, .topRightSixth)])
    func ultrawideTopEdgeIsSplitIntoSixthsAndMaximize(x: CGFloat, action: WindowAction) {
        #expect(resolve(CGPoint(x: x, y: 1), on: [Screens.ultrawide])?.action == action)
    }

    @Test func ultrawideCornersAreStillQuarters() {
        #expect(resolve(CGPoint(x: 1, y: 1), on: [Screens.ultrawide])?.action == .topLeft)
    }

    @Test func aSixteenByNineScreenIsNotUltrawide() {
        #expect(resolve(CGPoint(x: 600, y: 1), on: [Screens.studioDisplay])?.action == .maximize)
    }

    // MARK: Helpers

    private func resolve(_ point: CGPoint, on screens: [ScreenGeometry], previous: SnapMatch? = nil) -> SnapMatch? {
        SnapAreaResolver.resolve(cursor: point, screens: screens, previous: previous)
    }
}
