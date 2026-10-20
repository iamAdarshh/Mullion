import CoreGraphics
import Testing
@testable import MullionCore

struct DragSettingsTests {
    @Test func defaultsMatchThePRD() {
        #expect(DragSettings.defaults.edgeThickness == 5)
        #expect(DragSettings.defaults.cornerSize == 20)
    }

    @Test func valuesAreClamped() {
        let settings = DragSettings(edgeThickness: 0, cornerSize: 500)
        #expect(settings.edgeThickness == 1)
        #expect(settings.cornerSize == 100)
    }

    @Test func aCornerIsNeverThinnerThanAnEdge() {
        #expect(DragSettings(edgeThickness: 30, cornerSize: 10).cornerSize == 30)
    }

    // Regression: setting one value used to recurse forever through the other's `didSet`.
    @Test func changingTheEdgeThicknessClampsBothValues() {
        var settings = DragSettings()
        settings.edgeThickness = 30
        #expect(settings.edgeThickness == 30)
        #expect(settings.cornerSize == 30)
        settings.edgeThickness = 99
        #expect(settings.edgeThickness == 50)
    }

    @Test func changingTheCornerSizeClampsIt() {
        var settings = DragSettings(edgeThickness: 10, cornerSize: 20)
        settings.cornerSize = 4
        #expect(settings.cornerSize == 10)
        #expect(settings.edgeThickness == 10)
        settings.cornerSize = 500
        #expect(settings.cornerSize == 100)
    }
}
