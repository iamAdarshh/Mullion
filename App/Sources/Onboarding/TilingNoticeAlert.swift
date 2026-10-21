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
        // A menu bar app isn't active, so its alert would open behind the frontmost window. Remember who
        // was, and hand focus back afterwards: Mullion has no window to keep, and while it stays active
        // every shortcut would find no window to act on.
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        let choice: TilingNoticeChoice = alert.runModal() == .alertFirstButtonReturn ? .openSettings : .dontShowAgain
        if choice == .dontShowAgain, let previous, previous != NSRunningApplication.current {
            previous.activate()
        }
        completion(choice)
    }

    static func openSettings() {
        guard let url = URL(string: settingsURL) else {
            Log.app.error("Invalid Desktop & Dock settings URL")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// The notice's text, also shown in Settings → Drag.
    static func message(for conflicts: SystemTilingCheck.Conflicts) -> String {
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
