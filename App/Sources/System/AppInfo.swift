import AppKit

/// An app as the Ignored Apps tab shows it (PRD §6.8): name and icon looked up from its bundle ID.
struct AppInfo: Identifiable, Hashable {
    let bundleID: String
    let name: String

    var id: String {
        bundleID
    }

    /// The app's name, or its bundle ID if it isn't installed any more.
    init(bundleID: String) {
        self.bundleID = bundleID
        name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap(Self.name(at:)) ?? bundleID
    }

    init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }

    /// The app's Finder icon, or a generic app icon if it isn't installed.
    var icon: NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .application)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// The app at `url` (an `.app` bundle), or `nil` if it has no bundle ID.
    init?(url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
        self.init(bundleID: bundleID, name: Self.name(at: url) ?? bundleID)
    }

    /// Apps with a window in the Dock, minus `excluded` and Mullion itself, sorted by name: the ones
    /// worth offering in the *Add App* menu.
    static func running(excluding excluded: Set<String>) -> [AppInfo] {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0 != NSRunningApplication.current }
            .compactMap { app in
                app.bundleIdentifier.map { AppInfo(bundleID: $0, name: app.localizedName ?? $0) }
            }
        return sortedUnique(apps, excluding: excluded)
    }

    /// One entry per bundle ID, without `excluded`, sorted by name as Finder sorts.
    static func sortedUnique(_ apps: [AppInfo], excluding excluded: Set<String>) -> [AppInfo] {
        var seen = excluded
        return apps
            .filter { seen.insert($0.bundleID).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func name(at url: URL) -> String? {
        FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
