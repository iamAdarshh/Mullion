import CoreGraphics
import Testing
@testable import MullionCore

struct ScreenLocatorTests {
    @Test func picksTheScreenHoldingMostOfTheWindow() {
        // 70 pt on the laptop, 530 pt on the external display.
        let window = CGRect(x: 1400, y: 100, width: 600, height: 400)
        let screen = ScreenLocator.screen(containing: window, in: Screens.laptopLeftOfExternal)
        #expect(screen?.id == "studioRight")
    }

    @Test func picksAScreenAboveThePrimary() {
        let window = CGRect(x: 0, y: -900, width: 800, height: 600)
        #expect(ScreenLocator.screen(containing: window, in: Screens.externalAbovePrimary)?.id == "studioAbove")
    }

    @Test func picksAScreenLeftOfThePrimary() {
        let window = CGRect(x: -1000, y: 100, width: 800, height: 600)
        #expect(ScreenLocator.screen(containing: window, in: Screens.threeDisplays)?.id == "studioLeft")
    }

    @Test func offScreenWindowGoesToTheNearestScreen() {
        let window = CGRect(x: 5000, y: 0, width: 300, height: 300)
        #expect(ScreenLocator.screen(containing: window, in: Screens.threeDisplays)?.id == "portraitRight")
    }

    @Test func noScreensMeansNoResult() {
        #expect(ScreenLocator.screen(containing: .zero, in: []) == nil)
    }
}
