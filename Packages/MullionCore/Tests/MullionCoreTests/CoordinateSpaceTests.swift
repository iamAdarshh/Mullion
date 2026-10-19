import CoreGraphics
import Testing
@testable import MullionCore

struct CoordinateSpaceTests {
    /// The laptop is the primary screen in every arrangement; its height is the flip reference.
    private let space = CoordinateSpace(primaryScreenHeight: 956)

    @Test func primaryScreenMapsOntoItself() {
        let appKit = CGRect(x: 0, y: 0, width: 1470, height: 956)
        #expect(space.axRect(fromAppKit: appKit) == appKit)
    }

    @Test func screenAbovePrimaryHasNegativeAXY() {
        // In AppKit the display above starts where the primary ends (y = 956) and goes up.
        let appKit = CGRect(x: -545, y: 956, width: 2560, height: 1440)
        #expect(space.axRect(fromAppKit: appKit) == CGRect(x: -545, y: -1440, width: 2560, height: 1440))
    }

    @Test func screenBelowPrimaryHasAXYPastPrimaryHeight() {
        let appKit = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        #expect(space.axRect(fromAppKit: appKit) == CGRect(x: 0, y: 956, width: 1920, height: 1080))
    }

    @Test func menuBarStripOfPrimary() {
        // AppKit visibleFrame of the notched MacBook Air: everything below the 37 pt menu bar.
        let appKitVisible = CGRect(x: 0, y: 0, width: 1470, height: 919)
        #expect(space.axRect(fromAppKit: appKitVisible) == Screens.macBookAir13.visibleFrame)
    }

    @Test(arguments: Screens.all)
    func rectConversionRoundTrips(screen: ScreenGeometry) {
        let appKit = space.appKitRect(fromAX: screen.frame)
        #expect(space.axRect(fromAppKit: appKit) == screen.frame)
    }

    @Test func pointConversionFlipsY() {
        #expect(space.axPoint(fromAppKit: CGPoint(x: 100, y: 900)) == CGPoint(x: 100, y: 56))
        #expect(space.appKitPoint(fromAX: CGPoint(x: 100, y: 56)) == CGPoint(x: 100, y: 900))
        #expect(space.axPoint(fromAppKit: CGPoint(x: -10, y: 2000)) == CGPoint(x: -10, y: -1044))
    }
}
