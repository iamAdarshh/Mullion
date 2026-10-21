import Foundation
import MullionCore
import Testing

struct MullionConfigTests {
    private static let full = MullionConfig(
        general: .init(
            showsMenuBarIcon: false,
            repeatBehavior: .moveToNextDisplay,
            gap: 8,
            almostMaximizePercent: 85,
            resizeStep: 40,
            restoresSizeOnDragAway: false
        ),
        drag: .init(
            enabled: true,
            snapModifier: "control",
            edgeThickness: 6,
            cornerSize: 30,
            previewColor: "#FF8800",
            previewOpacity: 0.3,
            hapticFeedback: false,
            hidesTilingNotice: true
        ),
        shortcuts: [
            WindowAction.leftHalf.rawValue: .init(keyCode: 123, modifiers: 6144),
            WindowAction.center.rawValue: MullionConfig.Shortcut?.none,
        ],
        ignoredBundleIDs: ["com.apple.Notes", "com.apple.Safari"]
    )

    @Test func roundTrips() throws {
        let data = try Self.full.encoded()
        #expect(try MullionConfig.decode(data) == Self.full)
    }

    @Test func writesTheFormatAndCurrentVersion() throws {
        let json = try #require(String(data: Self.full.encoded(), encoding: .utf8))
        #expect(json.contains(#""format" : "mullion-config""#))
        #expect(json.contains(#""schemaVersion" : 1"#))
    }

    /// A cleared shortcut is kept as `null`, so it stays cleared on import instead of getting its
    /// default back.
    @Test func keepsClearedShortcutsApartFromMissingOnes() throws {
        let decoded = try MullionConfig.decode(Self.full.encoded())
        let center = try #require(decoded.shortcuts[WindowAction.center.rawValue])
        #expect(center == nil)
        #expect(decoded.shortcuts[WindowAction.rightHalf.rawValue] == nil)
    }

    /// A hand-written file may leave anything out: what's missing keeps its default on import.
    @Test func acceptsAMinimalFile() throws {
        let json = #"{ "format": "mullion-config", "schemaVersion": 1 }"#
        let config = try MullionConfig.decode(Data(json.utf8))
        #expect(config == MullionConfig())
    }

    @Test func ignoresUnknownFields() throws {
        let json = #"{ "format": "mullion-config", "schemaVersion": 1, "future": 1, "general": { "gap": 4, "x": 2 } }"#
        let config = try MullionConfig.decode(Data(json.utf8))
        #expect(config.general.gap == 4)
    }

    @Test(arguments: [
        #"{ "schemaVersion": 1 }"#,
        #"{ "format": "something-else", "schemaVersion": 1 }"#,
        #"[1, 2, 3]"#,
        "not json",
    ])
    func refusesFilesThatArentAConfig(json: String) {
        #expect(throws: MullionConfig.DecodingError.notAConfig) {
            try MullionConfig.decode(Data(json.utf8))
        }
    }

    @Test func refusesANewerVersion() {
        let json = #"{ "format": "mullion-config", "schemaVersion": 2 }"#
        #expect(throws: MullionConfig.DecodingError.newerVersion(2)) {
            try MullionConfig.decode(Data(json.utf8))
        }
    }

    @Test(arguments: [0, -1])
    func refusesAnImpossibleVersion(version: Int) {
        let json = #"{ "format": "mullion-config", "schemaVersion": \#(version) }"#
        #expect(throws: MullionConfig.DecodingError.notAConfig) {
            try MullionConfig.decode(Data(json.utf8))
        }
    }

    @Test func aWrongTypeIsInvalid() {
        let json = #"{ "format": "mullion-config", "schemaVersion": 1, "general": { "gap": "wide" } }"#
        #expect(throws: MullionConfig.DecodingError.invalid) {
            try MullionConfig.decode(Data(json.utf8))
        }
    }
}
