import AppKit
import MullionCore

/// *Copy Diagnostics* (PRD §6.8 Advanced): what a bug report needs, as plain text to paste into a
/// GitHub issue. In English on purpose, for whoever reads the issue. No window titles, and the
/// ignored apps only as a count.
struct Diagnostics {
    var appVersion: String
    var bundleID: String
    var macOSVersion: String
    var isTrusted: Bool
    /// In AX space, primary first.
    var screens: [ScreenGeometry]
    var tilingConflicts: SystemTilingCheck.Conflicts
    var config: MullionConfig

    var report: String {
        var lines = [
            "Mullion \(appVersion) (\(bundleID))",
            "macOS \(macOSVersion)",
            "Accessibility: \(isTrusted ? "granted" : "missing")",
            "Displays (\(screens.count)):",
        ]
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let size = "\(Int(frame.width))×\(Int(frame.height)) pt"
            let origin = "(\(Int(frame.minX)), \(Int(frame.minY)))"
            let primary = index == 0 ? ", primary" : ""
            lines.append("  \(index + 1): \(size) at \(origin), @\(Int(screen.scale))x\(primary)")
        }
        lines.append("macOS tiling: edge \(onOff(tilingConflicts.contains(.edgeTiling))), "
            + "⌥ \(onOff(tilingConflicts.contains(.optionTiling)))")
        lines.append("Ignored apps: \(config.ignoredBundleIDs?.count ?? 0)")

        var settings = config
        settings.ignoredBundleIDs = nil
        let json = (try? settings.encoded()).flatMap { String(data: $0, encoding: .utf8) } ?? "(unavailable)"
        lines.append("Settings:")
        lines.append(json)
        return lines.joined(separator: "\n")
    }

    private func onOff(_ isOn: Bool) -> String {
        isOn ? "on" : "off"
    }

    /// `27.0.1 (26A434)`. The system's own string reads "Version 27.0.1 (Build 26A434)".
    private static func macOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let number = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let build = ProcessInfo.processInfo.operatingSystemVersionString
            .split(separator: "Build ").last?
            .trimmingCharacters(in: CharacterSet(charactersIn: ") "))
        return build.map { "\(number) (\($0))" } ?? number
    }

    /// This Mac, now.
    @MainActor
    static func live(preferences: Preferences, isTrusted: Bool) -> Diagnostics {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return Diagnostics(
            appVersion: "\(short) (\(build))",
            bundleID: Bundle.main.bundleIdentifier ?? "?",
            macOSVersion: macOSVersion(),
            isTrusted: isTrusted,
            screens: SystemScreens().screens,
            tilingConflicts: SystemTilingCheck.live().conflicts(),
            config: ConfigTransfer.export(preferences: preferences, shortcuts: ShortcutStore())
        )
    }
}
