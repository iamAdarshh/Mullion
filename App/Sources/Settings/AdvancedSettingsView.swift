import SwiftUI

/// The Advanced tab (PRD §6.8): export and import the settings as a JSON file.
struct AdvancedSettingsView: View {
    let preferences: Preferences
    let shortcuts: any ShortcutStoring

    var body: some View {
        Form {
            Section {
                LabeledContent("Settings file") {
                    HStack {
                        Button("Export Settings…") {
                            ConfigFileActions.export(preferences: preferences, shortcuts: shortcuts)
                        }
                        Button("Import Settings…") {
                            ConfigFileActions.importSettings(preferences: preferences, shortcuts: shortcuts)
                        }
                    }
                }
            } footer: {
                Text("Settings, shortcuts and ignored apps, as JSON. Launch at login isn't included.")
                    .foregroundStyle(.secondary)
            }
        }
        .settingsForm()
    }
}
