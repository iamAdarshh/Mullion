import Foundation
import Testing
@testable import MullionCore

/// Version 1 is the first, so there are no upgrade steps yet; these cover the plumbing every
/// future step goes through.
struct ConfigMigratorTests {
    @Test func upgradingFromTheCurrentVersionKeepsTheFile() throws {
        let data = Data(#"{ "format": "mullion-config", "schemaVersion": 1, "general": { "gap": 4 } }"#.utf8)
        let upgraded = try ConfigMigrator.upgrade(data, from: MullionConfig.currentSchemaVersion)
        #expect(try MullionConfig.decode(upgraded).general.gap == 4)
    }

    @Test func aVersionWithoutAStepIsInvalid() {
        let data = Data(#"{ "format": "mullion-config", "schemaVersion": 0 }"#.utf8)
        #expect(throws: MullionConfig.DecodingError.invalid) {
            try ConfigMigrator.upgrade(data, from: 0)
        }
    }

    @Test func somethingOtherThanAnObjectIsNotAConfig() {
        #expect(throws: MullionConfig.DecodingError.notAConfig) {
            try ConfigMigrator.upgrade(Data("[1]".utf8), from: 0)
        }
    }
}
