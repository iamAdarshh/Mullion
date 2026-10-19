import CoreGraphics
import Testing
@testable import MullionCore

struct ActionPlannerTests {
    private static let laptop = [Screens.macBookAir13]
    private static let twoScreens = Screens.laptopLeftOfExternal
    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)
    private static let floating = CGRect(x: 100, y: 200, width: 600, height: 300)

    private func plan(
        _ action: WindowAction,
        window: CGRect = floating,
        screens: [ScreenGeometry] = laptop,
        lastSnap: SnapRecord? = nil,
        restoreFrame: CGRect? = nil,
        settings: ActionSettings = .defaults
    ) -> ActionPlan? {
        ActionPlanner.plan(
            action,
            for: WindowContext(frame: window, lastSnap: lastSnap, restoreFrame: restoreFrame),
            screens: screens,
            settings: settings
        )
    }

    // MARK: Plain actions

    @Test func tiledActionIsRecordedForCyclingAndDisplayMoves() {
        let result = plan(.leftHalf)
        #expect(result?.target == Self.leftHalf)
        #expect(result?.screen.id == "macBookAir13")
        #expect(result?.record == SnapRecord(action: .leftHalf, halfFraction: nil, frame: Self.leftHalf))
    }

    @Test func nonTiledActionIsNotRecorded() {
        let result = plan(.center)
        #expect(result?.target == CGRect(x: 435, y: 347, width: 600, height: 300))
        #expect(result?.record == nil)
    }

    @Test func noScreensMeansNoPlan() {
        #expect(plan(.leftHalf, screens: []) == nil)
    }

    // MARK: Repeat to cycle (PRD §6.2)

    @Test func repeatingAHalfCyclesTwoThirdsOneThirdHalf() {
        var last = SnapRecord(action: .leftHalf, halfFraction: nil, frame: Self.leftHalf)
        var widths: [CGFloat] = []
        for _ in 0 ..< 3 {
            guard let next = plan(.leftHalf, window: last.frame, lastSnap: last), let record = next.record else {
                Issue.record("Expected a plan with a record")
                return
            }
            widths.append(next.target.width)
            last = record
        }
        #expect(widths == [980, 490, 735])
    }

    @Test func aMovedWindowStartsAgainAtHalf() {
        let last = SnapRecord(
            action: .leftHalf,
            halfFraction: 2.0 / 3,
            frame: CGRect(x: 0, y: 37, width: 980, height: 919)
        )
        let result = plan(.leftHalf, window: Self.floating, lastSnap: last)
        #expect(result?.target == Self.leftHalf)
        #expect(result?.record?.halfFraction == nil)
    }

    @Test func aDifferentHalfDoesNotCycle() {
        let last = SnapRecord(action: .leftHalf, halfFraction: nil, frame: Self.leftHalf)
        let result = plan(.rightHalf, window: Self.leftHalf, lastSnap: last)
        #expect(result?.target == CGRect(x: 735, y: 37, width: 735, height: 919))
    }

    @Test func repeatDoesNothingWhenSetTo() {
        let last = SnapRecord(action: .leftHalf, halfFraction: nil, frame: Self.leftHalf)
        let settings = ActionSettings(repeatBehavior: .doNothing)
        #expect(plan(.leftHalf, window: Self.leftHalf, lastSnap: last, settings: settings) == nil)
    }

    @Test func repeatMovesToTheNextDisplayWhenSetTo() {
        let last = SnapRecord(action: .leftHalf, halfFraction: nil, frame: Self.leftHalf)
        let settings = ActionSettings(repeatBehavior: .moveToNextDisplay)
        let result = plan(
            .leftHalf,
            window: Self.leftHalf,
            screens: Self.twoScreens,
            lastSnap: last,
            settings: settings
        )
        #expect(result?.screen.id == "studioRight")
        #expect(result?.target == CGRect(x: 1470, y: -217, width: 1280, height: 1415))
    }

    @Test func repeatSetToNextDisplayStaysPutWithOneDisplay() {
        let last = SnapRecord(action: .leftHalf, halfFraction: nil, frame: Self.leftHalf)
        let settings = ActionSettings(repeatBehavior: .moveToNextDisplay)
        let result = plan(.leftHalf, window: Self.leftHalf, lastSnap: last, settings: settings)
        #expect(result?.target == Self.leftHalf)
    }

    @Test func recordTakesTheFrameTheWindowEndedUpWith() {
        let record = SnapRecord(action: .leftHalf, halfFraction: 2.0 / 3, frame: Self.leftHalf)
        let actual = CGRect(x: 0, y: 37, width: 800, height: 919)
        #expect(record.with(frame: actual) == SnapRecord(action: .leftHalf, halfFraction: 2.0 / 3, frame: actual))
    }

    // MARK: Next / previous display (PRD §6.5)

    @Test func snappedWindowKeepsItsActionOnTheNextDisplay() {
        let last = SnapRecord(action: .leftHalf, halfFraction: nil, frame: Self.leftHalf)
        let result = plan(.nextDisplay, window: Self.leftHalf, screens: Self.twoScreens, lastSnap: last)
        #expect(result?.target == CGRect(x: 1470, y: -217, width: 1280, height: 1415))
        #expect(result?.record?.action == .leftHalf)
    }

    @Test func snappedWindowKeepsItsCycleSizeOnTheNextDisplay() {
        let twoThirds = CGRect(x: 0, y: 37, width: 980, height: 919)
        let last = SnapRecord(action: .leftHalf, halfFraction: 2.0 / 3, frame: twoThirds)
        let result = plan(.nextDisplay, window: twoThirds, screens: Self.twoScreens, lastSnap: last)
        #expect(result?.target.width == 1707)
        #expect(result?.record?.halfFraction == 2.0 / 3)
    }

    @Test func unsnappedWindowIsScaledProportionally() {
        let result = plan(.nextDisplay, window: Self.floating, screens: Self.twoScreens)
        #expect(result?.screen.id == "studioRight")
        #expect(result?.record == nil)
        #expect(result.map { Self.twoScreens[1].visibleFrame.contains($0.target) } == true)
    }

    @Test func previousDisplayGoesLeft() {
        let result = plan(.previousDisplay, window: Self.floating, screens: Screens.threeDisplays)
        #expect(result?.screen.id == "studioLeft")
    }

    @Test func displayMovesNeedASecondScreen() {
        #expect(plan(.nextDisplay) == nil)
    }

    // MARK: Restore (PRD §6.3)

    @Test func restoreWithoutASavedFrameDoesNothing() {
        #expect(plan(.restore) == nil)
    }

    @Test func restoreReturnsTheSavedFrame() {
        let saved = CGRect(x: 300, y: 300, width: 500, height: 400)
        let result = plan(.restore, window: Self.leftHalf, restoreFrame: saved)
        #expect(result?.target == saved)
        #expect(result?.record == nil)
    }

    @Test func restoreToADisconnectedDisplayLandsOnAConnectedOne() {
        let saved = CGRect(x: 3000, y: 100, width: 500, height: 400)
        let result = plan(.restore, window: Self.leftHalf, restoreFrame: saved)
        #expect(result?.target == CGRect(x: 970, y: 100, width: 500, height: 400))
    }
}
