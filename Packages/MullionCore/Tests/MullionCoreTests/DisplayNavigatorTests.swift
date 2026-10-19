import CoreGraphics
import Testing
@testable import MullionCore

struct DisplayNavigatorTests {
    @Test func ordersLeftToRight() {
        let ids = DisplayNavigator.ordered(Screens.threeDisplays).map(\.id)
        #expect(ids == ["studioLeft", "macBookAir13", "portraitRight"])
    }

    @Test func screensWithTheSameXAreOrderedTopToBottom() {
        let below = ScreenGeometry(
            id: "below",
            frame: CGRect(x: 0, y: 956, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 981, width: 1920, height: 1055),
            scale: 1
        )
        let ids = DisplayNavigator.ordered([below, Screens.macBookAir13]).map(\.id)
        #expect(ids == ["macBookAir13", "below"])
    }

    @Test func externalAboveComesFirstBecauseItStartsFurtherLeft() {
        let ids = DisplayNavigator.ordered(Screens.externalAbovePrimary).map(\.id)
        #expect(ids == ["studioAbove", "macBookAir13"])
    }

    @Test func nextAndPreviousWrapAround() {
        let screens = Screens.threeDisplays
        let laptop = Screens.macBookAir13
        let portrait = screens[2]
        let studio = screens[1]

        #expect(DisplayNavigator.screen(.next, from: laptop, in: screens)?.id == "portraitRight")
        #expect(DisplayNavigator.screen(.next, from: portrait, in: screens)?.id == "studioLeft")
        #expect(DisplayNavigator.screen(.previous, from: studio, in: screens)?.id == "portraitRight")
        #expect(DisplayNavigator.screen(.previous, from: laptop, in: screens)?.id == "studioLeft")
    }

    @Test func aSingleScreenHasNoNeighbour() {
        #expect(DisplayNavigator.screen(.next, from: Screens.macBookAir13, in: [Screens.macBookAir13]) == nil)
    }

    @Test func proportionalFrameKeepsRelativePositionAndSize() {
        // 10 % in from the left, 20 % down; 50 % wide, 40 % tall. Laptop visible frame (0, 37, 1470, 919).
        let window = CGRect(x: 147, y: 220.8, width: 735, height: 367.6)
        let studio = Screens.laptopLeftOfExternal[1] // visible (1470, -217, 2560, 1415)

        let frame = DisplayNavigator.proportionalFrame(window, from: Screens.macBookAir13, to: studio)

        #expect(frame == CGRect(x: 1726, y: 66, width: 1280, height: 566))
    }

    @Test(arguments: Screens.all)
    func proportionalFrameStaysInsideTheDestination(screen: ScreenGeometry) {
        // A window hanging off the bottom-right of the laptop.
        let window = CGRect(x: 1200, y: 800, width: 600, height: 400)
        let frame = DisplayNavigator.proportionalFrame(window, from: Screens.macBookAir13, to: screen)
        #expect(screen.visibleFrame.contains(frame))
    }
}
