import AppKit
import MullionCore
import SwiftUI

/// The Advanced tab (PRD §6.8): export and import the settings, reset everything, and help with
/// bug reports.
struct AdvancedSettingsView: View {
    let preferences: Preferences
    let shortcuts: any ShortcutStoring
    let isTrusted: () -> Bool

    @State private var isConfirmingReset = false
    @State private var copiedDiagnostics = false

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
            Section {
                LabeledContent("Troubleshooting") {
                    HStack {
                        Button(copiedDiagnostics ? "Copied" : "Copy Diagnostics", action: copyDiagnostics)
                        Button("Open Console", action: openConsole)
                    }
                }
            } footer: {
                Text("""
                Diagnostics describe your Mac, displays and settings for a bug report, without the names \
                of your ignored apps. In Console, search for “mullion” and choose Action → Include Debug Messages.
                """)
                .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Start over") {
                    Button("Reset Everything…", role: .destructive) { isConfirmingReset = true }
                }
            }
        }
        .settingsForm()
        .confirmationDialog("Reset all of Mullion's settings?", isPresented: $isConfirmingReset) {
            Button("Reset Everything", role: .destructive, action: resetEverything)
        } message: {
            Text("Every setting, shortcut and ignored app goes back to its default. Launch at login is left as it is.")
        }
    }

    private func resetEverything() {
        ConfigTransfer.resetAll(preferences: preferences, shortcuts: shortcuts)
        Log.settings.info("Reset all settings")
    }

    private func copyDiagnostics() {
        let report = Diagnostics.live(preferences: preferences, isTrusted: isTrusted()).report
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        copiedDiagnostics = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedDiagnostics = false
        }
    }

    private func openConsole() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Console") else {
            Log.settings.error("Console.app not found")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
