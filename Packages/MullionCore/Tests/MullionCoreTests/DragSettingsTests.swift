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
}
