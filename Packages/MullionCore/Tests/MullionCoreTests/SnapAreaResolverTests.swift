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
            (CGPoint(x: frame.midX, y: frame.maxY - inset), screen.isPortrait ? .bottomHalf : .centerThird),
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

    @Test(arguments: Screens.all)
    func anAreaIsKeptUntilTheCursorIsEightPointsPastIt(screen: ScreenGeometry) {
        let frame = screen.frame
        let left = resolve(CGPoint(x: frame.minX + 1, y: frame.midY), on: [screen])
        #expect(resolve(CGPoint(x: frame.minX + 12.5, y: frame.midY), on: [screen], previous: left)?.area == .left)
        #expect(resolve(CGPoint(x: frame.minX + 13, y: frame.midY), on: [screen], previous: left) == nil)
    }

    @Test(arguments: Screens.all)
    func theCornerAndEdgeBoundaryDoesNotFlicker(screen: ScreenGeometry) {
        let screens = [screen]
        let x = screen.frame.minX + 1
        let top = screen.frame.minY
        let corner = resolve(CGPoint(x: x, y: top + 10), on: screens)
        #expect(corner?.area == .topLeft)
        // Just past the corner: still the corner, so a cursor wobbling on the line doesn't flicker.
        let wobble = resolve(CGPoint(x: x, y: top + 22), on: screens, previous: corner)
        #expect(wobble?.area == .topLeft)
        let edge = resolve(CGPoint(x: x, y: top + 28), on: screens, previous: wobble)
        #expect(edge?.area == .left)
        // And back again: the edge holds for 8 pt into the corner.
        #expect(resolve(CGPoint(x: x, y: top + 13), on: screens, previous: edge)?.area == .left)
        #expect(resolve(CGPoint(x: x, y: top + 11), on: screens, previous: edge)?.area == .topLeft)
    }

    @Test func anAreaIsKeptAcrossASharedEdgeBetweenDisplaysSideBySide() {
        let screens = Screens.laptopLeftOfExternal
        let right = resolve(CGPoint(x: 1469, y: 400), on: screens)
        let wobble = resolve(CGPoint(x: 1470, y: 400), on: screens, previous: right)
        #expect(wobble?.area == .right)
        #expect(wobble?.screen.id == "macBookAir13")
        #expect(resolve(CGPoint(x: 1477.5, y: 400), on: screens, previous: wobble)?.area == .right)
        // 8 pt into the external display the laptop's area is gone, and that spot is no area there.
        let gone = resolve(CGPoint(x: 1478, y: 400), on: screens, previous: wobble)
        #expect(gone == nil)
        // Coming back to the external display's edge from inside it snaps there.
        let left = resolve(CGPoint(x: 1471, y: 400), on: screens, previous: gone)
        #expect(left?.area == .left)
        #expect(left?.screen.id == "studioRight")
    }

    /// A point in an area next to an edge shared by two displays, and a point 1 pt over that edge on
    /// the neighbouring display.
    struct SharedEdge: Sendable, CustomTestStringConvertible {
        let screens: [ScreenGeometry]
        let start: CGPoint
        let over: CGPoint
        /// The screen the area belongs to.
        let owner: String

        var testDescription: String {
            "\(owner) at \(start) among \(screens.map(\.id).joined(separator: ", "))"
        }
    }

    static let sharedEdges = [
        SharedEdge(
            screens: Screens.laptopLeftOfExternal,
            start: CGPoint(x: 1469, y: 400),
            over: CGPoint(x: 1470, y: 400),
            owner: "macBookAir13"
        ),
        SharedEdge(
            screens: Screens.laptopLeftOfExternal,
            start: CGPoint(x: 1470, y: 400),
            over: CGPoint(x: 1469, y: 400),
            owner: "studioRight"
        ),
        SharedEdge(
            screens: Screens.externalAbovePrimary,
            start: CGPoint(x: 735, y: 1),
            over: CGPoint(x: 735, y: -1),
            owner: "macBookAir13"
        ),
        SharedEdge(
            screens: Screens.portraitLeftOfPrimary,
            start: CGPoint(x: 0, y: 400),
            over: CGPoint(x: -1, y: 400),
            owner: "macBookAir13"
        ),
        SharedEdge(
            screens: Screens.portraitLeftOfPrimary,
            start: CGPoint(x: -1, y: 400),
            over: CGPoint(x: 0, y: 400),
            owner: "portraitLeft"
        ),
        SharedEdge(
            screens: Screens.ultrawideLeftOfPrimary,
            start: CGPoint(x: 0, y: 400),
            over: CGPoint(x: -1, y: 400),
            owner: "macBookAir13"
        ),
        SharedEdge(
            screens: Screens.threeDisplays,
            start: CGPoint(x: -1, y: 400),
            over: CGPoint(x: 0, y: 400),
            owner: "studioLeft"
        ),
        SharedEdge(
            screens: Screens.threeDisplays,
            start: CGPoint(x: 1470, y: 400),
            over: CGPoint(x: 1469, y: 400),
            owner: "portraitRight"
        ),
    ]

    @Test(arguments: sharedEdges)
    func everySharedEdgeHoldsItsArea(edge: SharedEdge) {
        let first = resolve(edge.start, on: edge.screens)
        #expect(first?.screen.id == edge.owner)
        #expect(first != nil)
        #expect(resolve(edge.over, on: edge.screens, previous: first) == first)
    }

    @Test func anAreaIsKeptAcrossASharedEdgeBetweenDisplaysAboveAndBelow() {
        let screens = Screens.externalAbovePrimary
        let top = resolve(CGPoint(x: 735, y: 1), on: screens)
        let wobble = resolve(CGPoint(x: 735, y: -1), on: screens, previous: top)
        #expect(wobble?.action == .maximize)
        #expect(wobble?.screen.id == "macBookAir13")
        #expect(resolve(CGPoint(x: 735, y: -9), on: screens, previous: wobble) == nil)

        let above = resolve(CGPoint(x: 735, y: -1), on: screens)
        let downward = resolve(CGPoint(x: 735, y: 1), on: screens, previous: above)
        #expect(downward?.action == .centerThird)
        #expect(downward?.screen.id == "studioAbove")
    }

    // MARK: Bottom thirds

    @Test(arguments: Screens.landscape)
    func theBottomEdgeIsSplitIntoThirds(screen: ScreenGeometry) {
        let actions: [WindowAction] = [.firstThird, .centerThird, .lastThird]
        for (index, action) in actions.enumerated() {
            #expect(resolve(bottom(of: screen, at: (CGFloat(index) * 2 + 1) / 6), on: [screen])?.action == action)
        }
    }

    @Test(arguments: Screens.landscape)
    func slidingIntoTheNextThirdGivesTwoThirds(screen: ScreenGeometry) {
        let screens = [screen]
        let first = resolve(bottom(of: screen, at: 1 / 6), on: screens)
        let slid = resolve(bottom(of: screen, at: 1 / 2), on: screens, previous: first)
        #expect(slid?.action == .firstTwoThirds)
        // Back into the starting third: a single third again.
        #expect(resolve(bottom(of: screen, at: 1 / 6), on: screens, previous: slid)?.action == .firstThird)
        // On into the far third: the two thirds the cursor is now sliding between.
        #expect(resolve(bottom(of: screen, at: 5 / 6), on: screens, previous: slid)?.action == .lastTwoThirds)
    }

    @Test(arguments: Screens.landscape)
    func slidingOutOfTheCenterThirdGivesTwoThirds(screen: ScreenGeometry) {
        let screens = [screen]
        let center = resolve(bottom(of: screen, at: 1 / 2), on: screens)
        #expect(resolve(bottom(of: screen, at: 1 / 6), on: screens, previous: center)?.action == .firstTwoThirds)
        #expect(resolve(bottom(of: screen, at: 5 / 6), on: screens, previous: center)?.action == .lastTwoThirds)
    }

    @Test(arguments: Screens.landscape)
    func aBoundaryBetweenThirdsHasHysteresis(screen: ScreenGeometry) {
        let screens = [screen]
        let boundary = screen.frame.minX + screen.frame.width / 3
        let y = screen.frame.maxY - 1
        let first = resolve(CGPoint(x: boundary - 90, y: y), on: screens)
        #expect(resolve(CGPoint(x: boundary + 7, y: y), on: screens, previous: first)?.action == .firstThird)
        #expect(resolve(CGPoint(x: boundary + 8, y: y), on: screens, previous: first)?.action == .firstTwoThirds)
    }

    @Test(arguments: Screens.all.filter(\.isPortrait))
    func portraitScreensSnapTheBottomEdgeToTheBottomHalf(screen: ScreenGeometry) {
        #expect(resolve(bottom(of: screen, at: 1 / 2), on: [screen])?.action == .bottomHalf)
    }

    @Test func onlyNeighbouringThirdsCanBeSlidBetween() {
        #expect(BottomSlide(from: .first, to: .last) == nil)
        #expect(BottomSlide(from: .center, to: .center) == nil)
        #expect(BottomSlide(from: .last, to: .center)?.start == .last)
        #expect(BottomSlide(from: .last, to: .center)?.current == .center)
    }

    // MARK: Ultrawide

    @Test(arguments: Screens.ultrawideScreens)
    func ultrawideTopEdgeIsSplitIntoSixthsAndMaximize(screen: ScreenGeometry) {
        let actions: [WindowAction] = [.topLeftSixth, .maximize, .topRightSixth]
        for (index, action) in actions.enumerated() {
            let point = CGPoint(
                x: screen.frame.minX + screen.frame.width * (CGFloat(index) * 2 + 1) / 6,
                y: screen.frame.minY + 1
            )
            #expect(resolve(point, on: [screen])?.action == action)
        }
    }

    @Test(arguments: Screens.ultrawideScreens)
    func ultrawideCornersAreStillQuarters(screen: ScreenGeometry) {
        let point = CGPoint(x: screen.frame.minX + 1, y: screen.frame.minY + 1)
        #expect(resolve(point, on: [screen])?.action == .topLeft)
    }

    @Test func aSixteenByNineScreenIsNotUltrawide() {
        #expect(resolve(CGPoint(x: 600, y: 1), on: [Screens.studioDisplay])?.action == .maximize)
    }

    // MARK: Helpers

    private func resolve(_ point: CGPoint, on screens: [ScreenGeometry], previous: SnapMatch? = nil) -> SnapMatch? {
        SnapAreaResolver.resolve(cursor: point, screens: screens, previous: previous)
    }

    /// A point 1 pt above the bottom of `screen`, `fraction` of the way across it.
    private func bottom(of screen: ScreenGeometry, at fraction: CGFloat) -> CGPoint {
        CGPoint(x: screen.frame.minX + screen.frame.width * fraction, y: screen.frame.maxY - 1)
    }
}
