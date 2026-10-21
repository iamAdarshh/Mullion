import AppKit
import Testing
@testable import Mullion

struct HexColorTests {
    @Test(arguments: ["#000000", "#FFFFFF", "#0A84FF", "#C850C0"])
    func roundTrips(hex: String) throws {
        let color = try #require(HexColor.color(from: hex))
        #expect(HexColor.string(from: color) == hex)
    }

    @Test func acceptsAMissingHash() {
        #expect(HexColor.color(from: "0A84FF") != nil)
    }

    @Test(arguments: ["", "#12345", "#1234567", "#GG0000", "red"])
    func rejectsAnythingElse(text: String) {
        #expect(HexColor.color(from: text) == nil)
    }

    @Test func convertsOtherColourSpacesToSRGB() {
        #expect(HexColor.string(from: NSColor(white: 1, alpha: 1)) == "#FFFFFF")
    }
}
