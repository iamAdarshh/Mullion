import Foundation

/// Mullion's settings as one JSON document, for *Export Settings…* and *Import Settings…*
/// (ARCHITECTURE §8, PRD §6.8 Advanced).
///
/// Every value is optional: a file may leave anything out (it may be hand-written or partial), and
/// whatever is missing gets its default on import. Unknown fields are ignored. Values are stored as
/// written; the app clamps them to their valid ranges when it applies them, as it does for values in
/// `UserDefaults`.
public struct MullionConfig: Equatable, Sendable {
    /// The `format` value that marks a Mullion config file.
    public static let format = "mullion-config"
    /// The version this build writes. Older files are upgraded by `ConfigMigrator`.
    public static let currentSchemaVersion = 1

    /// Settings → General.
    public struct General: Codable, Equatable, Sendable {
        public var showsMenuBarIcon: Bool?
        public var repeatBehavior: ActionSettings.RepeatBehavior?
        public var gap: Double?
        public var almostMaximizePercent: Int?
        public var resizeStep: Double?
        public var restoresSizeOnDragAway: Bool?

        public init(
            showsMenuBarIcon: Bool? = nil,
            repeatBehavior: ActionSettings.RepeatBehavior? = nil,
            gap: Double? = nil,
            almostMaximizePercent: Int? = nil,
            resizeStep: Double? = nil,
            restoresSizeOnDragAway: Bool? = nil
        ) {
            self.showsMenuBarIcon = showsMenuBarIcon
            self.repeatBehavior = repeatBehavior
            self.gap = gap
            self.almostMaximizePercent = almostMaximizePercent
            self.resizeStep = resizeStep
            self.restoresSizeOnDragAway = restoresSizeOnDragAway
        }
    }

    /// Settings → Drag, and the tiling notice's *Don't Show Again*.
    public struct Drag: Codable, Equatable, Sendable {
        public var enabled: Bool?
        /// `option` or `control`.
        public var snapModifier: String?
        public var edgeThickness: Double?
        public var cornerSize: Double?
        /// `#RRGGBB` in sRGB; missing means the system accent colour.
        public var previewColor: String?
        public var previewOpacity: Double?
        public var hapticFeedback: Bool?
        public var hidesTilingNotice: Bool?

        public init(
            enabled: Bool? = nil,
            snapModifier: String? = nil,
            edgeThickness: Double? = nil,
            cornerSize: Double? = nil,
            previewColor: String? = nil,
            previewOpacity: Double? = nil,
            hapticFeedback: Bool? = nil,
            hidesTilingNotice: Bool? = nil
        ) {
            self.enabled = enabled
            self.snapModifier = snapModifier
            self.edgeThickness = edgeThickness
            self.cornerSize = cornerSize
            self.previewColor = previewColor
            self.previewOpacity = previewOpacity
            self.hapticFeedback = hapticFeedback
            self.hidesTilingNotice = hidesTilingNotice
        }
    }

    /// A key combination as Carbon codes, the form the hotkey library stores.
    public struct Shortcut: Codable, Equatable, Sendable {
        public var keyCode: Int
        public var modifiers: Int

        public init(keyCode: Int, modifiers: Int) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }
    }

    public var general: General
    public var drag: Drag
    /// By `WindowAction.rawValue`. A `nil` value (`null` in the file) is a shortcut the user cleared;
    /// an action that's missing gets its default shortcut.
    public var shortcuts: [String: Shortcut?]
    /// Apps whose windows never snap when dragged. Missing means none.
    public var ignoredBundleIDs: [String]?

    public init(
        general: General = General(),
        drag: Drag = Drag(),
        shortcuts: [String: Shortcut?] = [:],
        ignoredBundleIDs: [String]? = nil
    ) {
        self.general = general
        self.drag = drag
        self.shortcuts = shortcuts
        self.ignoredBundleIDs = ignoredBundleIDs
    }
}

// MARK: Reading and writing

public extension MullionConfig {
    /// Why a file can't be imported.
    enum DecodingError: Error, Equatable {
        /// Not JSON, or not a Mullion config.
        case notAConfig
        /// Written by a newer Mullion; this one can't know what its fields mean.
        case newerVersion(Int)
        /// A Mullion config, but a value has the wrong type.
        case invalid
    }

    /// Pretty-printed with sorted keys, so exported files are readable and diff cleanly.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Reads a config file, upgrading it if an older Mullion wrote it.
    static func decode(_ data: Data) throws(DecodingError) -> MullionConfig {
        guard let header = try? JSONDecoder().decode(Header.self, from: data),
              header.format == format,
              let version = header.schemaVersion, version >= 1
        else { throw .notAConfig }
        guard version <= currentSchemaVersion else { throw .newerVersion(version) }

        let current = version == currentSchemaVersion ? data : try ConfigMigrator.upgrade(data, from: version)
        do {
            return try JSONDecoder().decode(MullionConfig.self, from: current)
        } catch {
            throw .invalid
        }
    }

    /// The fields every version has, read before anything else.
    private struct Header: Decodable {
        let format: String?
        let schemaVersion: Int?
    }
}

extension MullionConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case format, schemaVersion, general, drag, shortcuts, ignoredBundleIDs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        general = try container.decodeIfPresent(General.self, forKey: .general) ?? General()
        drag = try container.decodeIfPresent(Drag.self, forKey: .drag) ?? Drag()
        shortcuts = try container.decodeIfPresent([String: Shortcut?].self, forKey: .shortcuts) ?? [:]
        ignoredBundleIDs = try container.decodeIfPresent([String].self, forKey: .ignoredBundleIDs)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.format, forKey: .format)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(general, forKey: .general)
        try container.encode(drag, forKey: .drag)
        try container.encode(shortcuts, forKey: .shortcuts)
        try container.encodeIfPresent(ignoredBundleIDs, forKey: .ignoredBundleIDs)
    }
}
