import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Ignored Apps tab (PRD §6.8): apps whose windows never snap when dragged. Shortcuts and the
/// menu still act on them.
struct IgnoredAppsSettingsView: View {
    let preferences: Preferences

    var body: some View {
        Form {
            Section {
                if apps.isEmpty {
                    Text("No apps are ignored.")
                        .foregroundStyle(.secondary)
                }
                ForEach(apps) { app in
                    AppRow(app: app) { preferences.setIgnored(false, bundleID: app.bundleID) }
                }
            } footer: {
                HStack {
                    Text("Windows of these apps never snap when dragged. Keyboard shortcuts still work.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    addMenu
                }
            }
        }
        .settingsForm()
    }

    private var apps: [AppInfo] {
        AppInfo.sortedUnique(preferences.ignoredBundleIDs.map(AppInfo.init(bundleID:)), excluding: [])
    }

    private var addMenu: some View {
        Menu("Add App") {
            // Read when the menu opens, so it lists the apps running now.
            ForEach(AppInfo.running(excluding: preferences.ignoredBundleIDs)) { app in
                Button {
                    preferences.setIgnored(true, bundleID: app.bundleID)
                } label: {
                    Label { Text(app.name) } icon: { Image(nsImage: app.icon) }
                }
            }
            Divider()
            Button("Choose from Applications…", action: chooseApp)
        }
        .fixedSize()
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = String(
            localized: "Ignore",
            comment: "Open panel button: adds the chosen apps to the ignore list"
        )
        guard panel.runModal() == .OK else { return }
        for app in panel.urls.compactMap(AppInfo.init(url:)) {
            preferences.setIgnored(true, bundleID: app.bundleID)
        }
    }
}

private struct AppRow: View {
    let app: AppInfo
    let remove: () -> Void

    var body: some View {
        HStack {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(app.name)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(Text("Stop ignoring \(app.name)"))
            .accessibilityLabel(Text("Stop ignoring \(app.name)"))
        }
    }
}
