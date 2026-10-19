import CoreGraphics
import Testing
@testable import MullionCore

struct ActionCalculatorTests {
    private static let anyWindow = CGRect(x: 100, y: 200, width: 600, height: 300)

    private func target(
        _ action: WindowAction,
        on screen: ScreenGeometry,
        window: CGRect = anyWindow,
        settings: ActionSettings = .defaults,
        fraction: CGFloat? = nil
    ) -> CGRect? {
        ActionCalculator.targetRect(
            for: action, window: window, screen: screen, settings: settings, halfFraction: fraction
        )
    }

    // MARK: Exact rects

    /// Visible frame (0, 37, 1470, 919): 37 pt notched menu bar, no Dock.
    private static let macBookAir13Cases: [(WindowAction, CGRect)] = [
        (.leftHalf, CGRect(x: 0, y: 37, width: 735, height: 919)),
        (.rightHalf, CGRect(x: 735, y: 37, width: 735, height: 919)),
        (.topHalf, CGRect(x: 0, y: 37, width: 1470, height: 460)),
        (.bottomHalf, CGRect(x: 0, y: 497, width: 1470, height: 459)),
        (.topLeft, CGRect(x: 0, y: 37, width: 735, height: 460)),
        (.topRight, CGRect(x: 735, y: 37, width: 735, height: 460)),
        (.bottomLeft, CGRect(x: 0, y: 497, width: 735, height: 459)),
        (.bottomRight, CGRect(x: 735, y: 497, width: 735, height: 459)),
        (.firstThird, CGRect(x: 0, y: 37, width: 490, height: 919)),
        (.centerThird, CGRect(x: 490, y: 37, width: 490, height: 919)),
        (.lastThird, CGRect(x: 980, y: 37, width: 490, height: 919)),
        (.firstTwoThirds, CGRect(x: 0, y: 37, width: 980, height: 919)),
        (.lastTwoThirds, CGRect(x: 490, y: 37, width: 980, height: 919)),
        (.topLeftSixth, CGRect(x: 0, y: 37, width: 490, height: 460)),
        (.topCenterSixth, CGRect(x: 490, y: 37, width: 490, height: 460)),
        (.topRightSixth, CGRect(x: 980, y: 37, width: 490, height: 460)),
        (.bottomLeftSixth, CGRect(x: 0, y: 497, width: 490, height: 459)),
        (.bottomCenterSixth, CGRect(x: 490, y: 497, width: 490, height: 459)),
        (.bottomRightSixth, CGRect(x: 980, y: 497, width: 490, height: 459)),
        (.maximize, CGRect(x: 0, y: 37, width: 1470, height: 919)),
        (.almostMaximize, CGRect(x: 74, y: 83, width: 1323, height: 827)),
        (.maximizeHeight, CGRect(x: 100, y: 37, width: 600, height: 919)),
        (.center, CGRect(x: 435, y: 347, width: 600, height: 300)),
        (.larger, CGRect(x: 70, y: 170, width: 660, height: 360)),
        (.smaller, CGRect(x: 130, y: 230, width: 540, height: 240)),
    ]

    @Test(arguments: macBookAir13Cases)
    func macBookAir13(action: WindowAction, expected: CGRect) {
        #expect(target(action, on: Screens.macBookAir13) == expected)
    }

    /// Portrait: thirds and sixths are laid out top to bottom. Visible frame (0, 25, 1080, 1895).
    private static let portrait1080Cases: [(WindowAction, CGRect)] = [
        (.leftHalf, CGRect(x: 0, y: 25, width: 540, height: 1895)),
        (.firstThird, CGRect(x: 0, y: 25, width: 1080, height: 632)),
        (.centerThird, CGRect(x: 0, y: 657, width: 1080, height: 631)),
        (.lastThird, CGRect(x: 0, y: 1288, width: 1080, height: 632)),
        (.firstTwoThirds, CGRect(x: 0, y: 25, width: 1080, height: 1263)),
        (.lastTwoThirds, CGRect(x: 0, y: 657, width: 1080, height: 1263)),
        (.topLeftSixth, CGRect(x: 0, y: 25, width: 540, height: 632)),
        (.topCenterSixth, CGRect(x: 540, y: 25, width: 540, height: 632)),
        (.topRightSixth, CGRect(x: 0, y: 657, width: 540, height: 631)),
        (.bottomLeftSixth, CGRect(x: 540, y: 657, width: 540, height: 631)),
        (.bottomCenterSixth, CGRect(x: 0, y: 1288, width: 540, height: 632)),
        (.bottomRightSixth, CGRect(x: 540, y: 1288, width: 540, height: 632)),
    ]

    @Test(arguments: portrait1080Cases)
    func portrait1080(action: WindowAction, expected: CGRect) {
        #expect(target(action, on: Screens.portrait1080) == expected)
    }

    /// A non-primary display above the primary: negative AX coordinates. Visible (-545, -1415, 2560, 1415).
    private static let displayAbovePrimaryCases: [(WindowAction, CGRect)] = [
        (.leftHalf, CGRect(x: -545, y: -1415, width: 1280, height: 1415)),
        (.topHalf, CGRect(x: -545, y: -1415, width: 2560, height: 707)),
        (.bottomHalf, CGRect(x: -545, y: -708, width: 2560, height: 708)),
        (.firstThird, CGRect(x: -545, y: -1415, width: 853, height: 1415)),
        (.lastThird, CGRect(x: 1162, y: -1415, width: 853, height: 1415)),
        (.maximize, CGRect(x: -545, y: -1415, width: 2560, height: 1415)),
    ]

    @Test(arguments: displayAbovePrimaryCases)
    func displayAbovePrimary(action: WindowAction, expected: CGRect) {
        #expect(target(action, on: Screens.externalAbovePrimary[1]) == expected)
    }

    private static let gapOf10Cases: [(WindowAction, CGRect)] = [
        (.leftHalf, CGRect(x: 10, y: 47, width: 720, height: 899)),
        (.rightHalf, CGRect(x: 740, y: 47, width: 720, height: 899)),
        (.maximize, CGRect(x: 10, y: 47, width: 1450, height: 899)),
        (.maximizeHeight, CGRect(x: 100, y: 47, width: 600, height: 899)),
        // Not tiled, so no gap.
        (.almostMaximize, CGRect(x: 74, y: 83, width: 1323, height: 827)),
        (.center, CGRect(x: 435, y: 347, width: 600, height: 300)),
    ]

    @Test(arguments: gapOf10Cases)
    func gapOf10(action: WindowAction, expected: CGRect) {
        var settings = ActionSettings.defaults
        settings.gap = 10
        #expect(target(action, on: Screens.macBookAir13, settings: settings) == expected)
    }

    @Test func dockOnTheLeftShiftsEverything() {
        // Visible (64, 37, 1406, 919)
        #expect(target(.leftHalf, on: Screens.macBookAir13DockLeft) == CGRect(x: 64, y: 37, width: 703, height: 919))
    }

    // MARK: Cycle fractions

    struct HalfFractionCase: Sendable {
        let action: WindowAction
        let fraction: CGFloat
        let expected: CGRect

        init(_ action: WindowAction, _ fraction: CGFloat, _ expected: CGRect) {
            self.action = action
            self.fraction = fraction
            self.expected = expected
        }
    }

    private static let halfFractionsCases: [HalfFractionCase] = [
        HalfFractionCase(.leftHalf, 2.0 / 3, CGRect(x: 0, y: 37, width: 980, height: 919)),
        HalfFractionCase(.leftHalf, 1.0 / 3, CGRect(x: 0, y: 37, width: 490, height: 919)),
        HalfFractionCase(.rightHalf, 2.0 / 3, CGRect(x: 490, y: 37, width: 980, height: 919)),
        HalfFractionCase(.topHalf, 1.0 / 3, CGRect(x: 0, y: 37, width: 1470, height: 306)),
        HalfFractionCase(.bottomHalf, 2.0 / 3, CGRect(x: 0, y: 343, width: 1470, height: 613)),
    ]

    @Test(arguments: halfFractionsCases)
    func halfFractions(testCase: HalfFractionCase) {
        #expect(target(testCase.action, on: Screens.macBookAir13, fraction: testCase.fraction) == testCase.expected)
    }

    @Test func fractionIsIgnoredForNonHalves() {
        #expect(target(.maximize, on: Screens.macBookAir13, fraction: 1.0 / 3) == Screens.macBookAir13.visibleFrame)
    }

    // MARK: Window-relative actions

    @Test func centerShrinksAWindowLargerThanTheScreen() {
        let huge = CGRect(x: -100, y: 0, width: 2000, height: 1200)
        #expect(target(.center, on: Screens.macBookAir13, window: huge) == Screens.macBookAir13.visibleFrame)
    }

    @Test func largerStopsAtTheScreenEdge() {
        let flushLeft = CGRect(x: 0, y: 37, width: 600, height: 300)
        #expect(target(.larger, on: Screens.macBookAir13, window: flushLeft) == CGRect(
            x: 0, y: 37, width: 630, height: 330
        ))
    }

    @Test func largerOnAWindowOffTheScreenMovesItBack() {
        let offScreen = CGRect(x: 2000, y: 2000, width: 600, height: 300)
        #expect(target(.larger, on: Screens.macBookAir13, window: offScreen) == CGRect(
            x: 810, y: 596, width: 660, height: 360
        ))
    }

    /// Regression: Grow used to crop the part of the window outside the visible frame.
    @Test func largerNeverShrinksAWindowPartlyPastTheScreenEdge() {
        let pastRightEdge = CGRect(x: 1200, y: 200, width: 600, height: 400)
        #expect(target(.larger, on: Screens.macBookAir13, window: pastRightEdge) == CGRect(
            x: 1170, y: 170, width: 630, height: 460
        ))
    }

    @Test(arguments: Screens.all)
    func largerAlwaysContainsTheOriginalWindow(screen: ScreenGeometry) {
        let visible = screen.visibleFrame
        let windows = [
            CGRect(x: visible.midX, y: visible.midY, width: 400, height: 300),
            CGRect(x: visible.maxX - 100, y: visible.minY + 50, width: 400, height: 300),
            CGRect(x: visible.minX - 200, y: visible.maxY - 100, width: 400, height: 300),
            CGRect(x: visible.midX, y: visible.minY - 50, width: 400, height: 300),
        ]
        for window in windows {
            let grown = target(.larger, on: screen, window: window)
            #expect(grown.map { $0.contains(window) } == true, "\(window)")
        }
    }

    @Test func smallerStopsAtAQuarterOfTheScreen() {
        // 400 - 60 < 25 % of 1470 and 250 - 60 < 25 % of 919, so neither dimension shrinks.
        let small = CGRect(x: 100, y: 200, width: 400, height: 250)
        #expect(target(.smaller, on: Screens.macBookAir13, window: small) == small)
    }

    @Test(arguments: [WindowAction.restore, .nextDisplay, .previousDisplay])
    func actionsThatNeedMoreThanTheScreenReturnNil(action: WindowAction) {
        #expect(target(action, on: Screens.macBookAir13) == nil)
    }

    // MARK: Invariants on every screen

    private static let tiledActions = WindowAction.allCases.filter(\.isTiled)

    @Test(arguments: Screens.all)
    func tiledRectsStayInsideTheVisibleFrame(screen: ScreenGeometry) {
        for gap: CGFloat in [0, 10, 40] {
            var settings = ActionSettings.defaults
            settings.gap = gap
            for action in Self.tiledActions {
                let rect = target(action, on: screen, settings: settings)
                #expect(rect.map { screen.visibleFrame.contains($0) } == true, "\(action) gap \(gap)")
            }
        }
    }

    @Test(arguments: Screens.all)
    func groupsTileTheVisibleFrameExactly(screen: ScreenGeometry) {
        let groups: [[WindowAction]] = [
            [.leftHalf, .rightHalf],
            [.topHalf, .bottomHalf],
            [.topLeft, .topRight, .bottomLeft, .bottomRight],
            [.firstThird, .centerThird, .lastThird],
            [.firstThird, .lastTwoThirds],
            [.firstTwoThirds, .lastThird],
            [.topLeftSixth, .topCenterSixth, .topRightSixth, .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth],
        ]
        for group in groups {
            let rects = group.compactMap { target($0, on: screen) }
            let area = rects.map(\.area).reduce(0, +)
            let union = rects.reduce(CGRect.null) { $0.union($1) }
            #expect(area == screen.visibleFrame.area, "\(group)")
            #expect(union == screen.visibleFrame, "\(group)")
        }
    }

    @Test(arguments: Screens.all)
    func neighboursAreExactlyOneGapApart(screen: ScreenGeometry) {
        var settings = ActionSettings.defaults
        settings.gap = 12
        let left = target(.leftHalf, on: screen, settings: settings)
        let right = target(.rightHalf, on: screen, settings: settings)
        let gap = (right?.minX ?? 0) - (left?.maxX ?? 0)
        #expect(abs(gap - 12) <= 1)
    }

    @Test(arguments: Screens.all)
    func everyResultIsWholePoints(screen: ScreenGeometry) {
        for action in WindowAction.allCases {
            guard let rect = target(action, on: screen) else { continue }
            #expect(rect == rect.integral, "\(action)")
        }
    }

    // MARK: Minimum size (AC-2)

    @Test func reanchoredKeepsTheTargetOriginWhenItFits() {
        let rect = ActionCalculator.reanchored(
            actual: CGRect(x: 300, y: 300, width: 500, height: 600),
            target: CGRect(x: 0, y: 37, width: 490, height: 919),
            visibleFrame: Screens.macBookAir13.visibleFrame
        )
        #expect(rect == CGRect(x: 0, y: 37, width: 500, height: 600))
    }

    @Test func reanchoredMovesAnOversizedWindowBackOnScreen() {
        let rect = ActionCalculator.reanchored(
            actual: CGRect(x: 735, y: 37, width: 800, height: 919),
            target: CGRect(x: 735, y: 37, width: 735, height: 919),
            visibleFrame: Screens.macBookAir13.visibleFrame
        )
        #expect(rect == CGRect(x: 670, y: 37, width: 800, height: 919))
    }

    @Test(arguments: Screens.all)
    func reanchoredNeverLeavesTheScreen(screen: ScreenGeometry) {
        let visible = screen.visibleFrame
        let rect = ActionCalculator.reanchored(
            actual: CGRect(x: 0, y: 0, width: visible.width * 0.8, height: visible.height * 0.9),
            target: CGRect(x: visible.maxX - 100, y: visible.maxY - 100, width: 100, height: 100),
            visibleFrame: visible
        )
        #expect(visible.contains(rect))
    }
}
