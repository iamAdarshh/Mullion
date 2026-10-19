import CoreGraphics
import Testing
@testable import MullionCore

struct ActionSettingsTests {
    @Test func defaultsMatchThePRD() {
        let settings = ActionSettings.defaults
        #expect(settings.gap == 0)
        #expect(settings.almostMaximizeFraction == 0.9)
        #expect(settings.resizeStep == 30)
        #expect(settings.repeatBehavior == .cycleSizes)
    }

    @Test func initClampsOutOfRangeValues() {
        let settings = ActionSettings(gap: 100, almostMaximizeFraction: 0.1, resizeStep: -5)
        #expect(settings.gap == 40)
        #expect(settings.almostMaximizeFraction == 0.5)
        #expect(settings.resizeStep == 1)
    }

    @Test func settingClampsOutOfRangeValues() {
        var settings = ActionSettings.defaults
        settings.gap = -3
        settings.almostMaximizeFraction = 1.5
        settings.resizeStep = 0
        #expect(settings.gap == 0)
        #expect(settings.almostMaximizeFraction == 1)
        #expect(settings.resizeStep == 1)
    }
}
