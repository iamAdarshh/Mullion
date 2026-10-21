import Foundation

/// Reads whether macOS's own window tiling (macOS 15 and later) is on, which conflicts with drag to
/// snap (PRD §6.6). Only ever reads `com.apple.WindowManager`; Mullion never changes these settings.
struct SystemTilingCheck {
    /// The macOS tiling settings that get in the way of drag to snap.
    struct Conflicts: OptionSet, Equatable {
        let rawValue: Int

        /// "Drag windows to screen edges to tile" or "Drag windows to menu bar to fill screen": macOS
        /// tiles a window dropped where Mullion would snap it.
        static let edgeTiling = Conflicts(rawValue: 1 << 0)
        /// "Hold ⌥ key while dragging windows to tile": the ⌥ that turns Mullion's snapping off hands
        /// the drag to macOS instead.
        static let optionTiling = Conflicts(rawValue: 1 << 1)

        /// The conflicts that matter with these settings (PRD §6.6): none while drag to snap is off,
        /// and ⌥-drag tiling only while ⌥ is Mullion's snap modifier too.
        func relevant(dragToSnap: Bool, snapModifier: SnapModifier) -> Conflicts {
            guard dragToSnap else { return [] }
            return snapModifier == .option ? self : subtracting(.optionTiling)
        }
    }

    static let domain = "com.apple.WindowManager"
    static let edgeTilingKey = "EnableTilingByEdgeDrag"
    static let topEdgeTilingKey = "EnableTopTilingByEdgeDrag"
    static let optionTilingKey = "EnableTilingOptionAccelerator"

    /// Whether this macOS has window tiling at all (macOS 15 and later).
    let hasSystemTiling: Bool
    /// A value from the `com.apple.WindowManager` domain, or `nil` when the user never changed it.
    let value: (String) -> Any?

    /// The settings on this Mac.
    static func live() -> SystemTilingCheck {
        let defaults = UserDefaults(suiteName: domain)
        return SystemTilingCheck(
            hasSystemTiling: ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)
            ),
            value: { defaults?.object(forKey: $0) }
        )
    }

    /// The settings that are on right now. Empty before macOS 15.
    func conflicts() -> Conflicts {
        guard hasSystemTiling else { return [] }
        var conflicts: Conflicts = []
        if isOn(Self.edgeTilingKey) || isOn(Self.topEdgeTilingKey) {
            conflicts.insert(.edgeTiling)
        }
        if isOn(Self.optionTilingKey) {
            conflicts.insert(.optionTiling)
        }
        return conflicts
    }

    /// A setting the user never changed is missing from the domain and has its default: on. Values
    /// come back as numbers (`defaults write … -int 0` stores an integer), so 0 is off.
    private func isOn(_ key: String) -> Bool {
        (value(key) as? NSNumber)?.boolValue ?? true
    }
}
