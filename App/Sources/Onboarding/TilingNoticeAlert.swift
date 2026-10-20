import AppKit

/// The tiling notice as an alert (PRD §6.6). Names the macOS settings to turn off, using their titles
/// in *System Settings → Desktop & Dock → Windows*.
@MainActor
struct TilingNoticeAlert: TilingNoticePresenting {
    /// *Desktop & Dock* in System Settings.
    static let settingsURL = "x-apple.systempreferences:com.apple.Desktop-Settings.extension"

    func present(_ conflicts: SystemTilingCheck.Conflicts, completion: @escaping (TilingNoticeChoice) -> Void) {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "macOS is also tiling windows",
            comment: "Title of the notice shown when macOS window tiling is on."
        )
        alert.informativeText = Self.message(for: conflicts)
        alert.addButton(withTitle: String(
            localized: "Open Desktop & Dock Settings",
            comment: "Button: opens System Settings so the user can turn macOS tiling off."
        ))
        alert.addButton(withTitle: String(
            localized: "Don't Show Again",
            comment: "Button: never show the macOS tiling notice again."
        ))
        // A menu bar app isn't active, so its alert would open behind the frontmost window.
        NSApp.activate()
        let response = alert.runModal()
        completion(response == .alertFirstButtonReturn ? .openSettings : .dontShowAgain)
    }

    static func openSettings() {
        guard let url = URL(string: settingsURL) else {
            Log.app.error("Invalid Desktop & Dock settings URL")
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func message(for conflicts: SystemTilingCheck.Conflicts) -> String {
        var paragraphs: [String] = []
        if conflicts.contains(.edgeTiling) {
            paragraphs.append(String(
                localized: """
                macOS tiles windows you drag to the screen edges or the menu bar, so macOS and Mullion both \
                act on the same drag. In Desktop & Dock, turn off “Drag windows to screen edges to tile” and \
                “Drag windows to menu bar to fill screen”.
                """,
                comment: "Notice text when macOS edge tiling is on. The quoted names are macOS setting titles."
            ))
        }
        if conflicts.contains(.optionTiling) {
            paragraphs.append(String(
                localized: """
                Holding ⌥ while dragging tiles the window with macOS instead of moving it without snapping. \
                In Desktop & Dock, turn off “Hold ⌥ key while dragging windows to tile”.
                """,
                comment: "Notice text when macOS ⌥-drag tiling is on. The quoted name is a macOS setting title."
            ))
        }
        return paragraphs.joined(separator: "\n\n")
    }
}
