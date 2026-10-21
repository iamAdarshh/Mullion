import Foundation

/// Upgrades a config file written by an older Mullion to the current schema, one version at a time
/// (ARCHITECTURE §8). Each step rewrites the JSON object; the result is decoded as usual.
///
/// Version 1 is the first, so there are no steps yet. When the schema changes: bump
/// `MullionConfig.currentSchemaVersion`, add a step from the previous version here, and add a test
/// that decodes a file of the old version.
enum ConfigMigrator {
    static func upgrade(_ data: Data, from version: Int) throws(MullionConfig.DecodingError) -> Data {
        guard var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw .notAConfig
        }
        for from in version ..< MullionConfig.currentSchemaVersion {
            object = try step(from: from, object)
        }
        object["schemaVersion"] = MullionConfig.currentSchemaVersion
        guard let upgraded = try? JSONSerialization.data(withJSONObject: object) else { throw .invalid }
        return upgraded
    }

    /// Upgrades `object` from version `from` to `from + 1`.
    private static func step(from version: Int, _: [String: Any]) throws(MullionConfig.DecodingError) -> [String: Any] {
        switch version {
        // case 1: rename or reshape fields for version 2, and return the new object.
        default: throw .invalid
        }
    }
}
