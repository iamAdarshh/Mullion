import AppKit
import MullionCore
import UniformTypeIdentifiers

/// *Export Settings…* and *Import Settings…* (PRD §6.8 Advanced): the file panels and alerts around
/// `ConfigTransfer`.
@MainActor
enum ConfigFileActions {
    static let fileName = "mullion-config.json"

    static func export(preferences: Preferences, shortcuts: any ShortcutStoring) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let config = ConfigTransfer.export(preferences: preferences, shortcuts: shortcuts)
            try config.encoded().write(to: url, options: .atomic)
            Log.settings.info("Exported settings")
        } catch {
            // Private: the error names the file's path, which includes the user's name.
            Log.settings.error("Couldn't export settings: \(error, privacy: .private)")
            showError(String(
                localized: "Mullion couldn't save “\(url.lastPathComponent)”.",
                comment: "Export failed. The name is the file's."
            ), detail: error.localizedDescription)
        }
    }

    static func importSettings(preferences: Preferences, shortcuts: any ShortcutStoring) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = url.lastPathComponent
        let config: MullionConfig
        do {
            config = try MullionConfig.decode(Data(contentsOf: url))
        } catch let error as MullionConfig.DecodingError {
            Log.settings.error("Couldn't import settings: \(String(describing: error), privacy: .public)")
            showError(message(for: error, name: name), detail: nil)
            return
        } catch {
            Log.settings.error("Couldn't read the settings file: \(error, privacy: .private)")
            showError(String(
                localized: "Mullion couldn't read “\(name)”.",
                comment: "Import failed: the file couldn't be opened. The name is the file's."
            ), detail: error.localizedDescription)
            return
        }
        guard confirmImport(name: name) else { return }
        ConfigTransfer.apply(config, to: preferences, shortcuts: shortcuts)
        Log.settings.info("Imported settings")
    }

    // MARK: Private

    private static func message(for error: MullionConfig.DecodingError, name: String) -> String {
        switch error {
        case .notAConfig:
            String(
                localized: "“\(name)” isn't a Mullion settings file.",
                comment: "Import failed. The name is the file's."
            )
        case .newerVersion:
            String(
                localized: "“\(name)” was exported by a newer version of Mullion. Update Mullion to import it.",
                comment: "Import failed. The name is the file's."
            )
        case .invalid:
            String(
                localized: "“\(name)” has a value Mullion can't read.",
                comment: "Import failed: a value has the wrong type. The name is the file's."
            )
        }
    }

    private static func confirmImport(name: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Replace your settings with the ones in “\(name)”?",
            comment: "Import confirmation. The name is the file's."
        )
        alert.informativeText = String(
            localized: """
            All settings, shortcuts and ignored apps are replaced. Anything the file leaves out goes back to \
            its default.
            """,
            comment: "Import confirmation details."
        )
        alert.addButton(withTitle: String(localized: "Replace", comment: "Import confirmation button"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func showError(_ message: String, detail: String?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail ?? ""
        alert.runModal()
    }
}
