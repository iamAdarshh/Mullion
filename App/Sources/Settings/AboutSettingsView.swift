import AppKit
import SwiftUI

/// The About tab (PRD §6.8): version, licence, source code and acknowledgements. The links open in
/// the browser; Mullion itself never goes online (NFR-3).
struct AboutSettingsView: View {
    // Fixed, known-good literals, so unwrapping can't fail.
    private static let repository = URL(string: "https://github.com/iamAdarshh/Mullion")!
    private static let license = URL(string: "https://github.com/iamAdarshh/Mullion/blob/main/LICENSE")!
    private static let keyboardShortcuts = URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mullion").font(.title2).bold()
                        Text("Version \(Self.version)", comment: "For example: Version 1.0.0 (12)")
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("A free, open-source window manager for macOS.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                LabeledContent("Licence") {
                    Link("MIT", destination: Self.license)
                }
                LabeledContent("Source code") {
                    Link("GitHub", destination: Self.repository)
                }
            }
            Section("Acknowledgements") {
                LabeledContent {
                    Link("MIT", destination: Self.keyboardShortcuts)
                } label: {
                    Text(verbatim: "KeyboardShortcuts")
                    Text(verbatim: "Sindre Sorhus")
                }
            }
        }
        .settingsForm()
    }

    /// `1.0.0 (12)`: the marketing version and the build number.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
