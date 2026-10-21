import Testing
@testable import Mullion

struct AppInfoTests {
    @Test func sortsByNameAsFinderDoes() {
        let apps = [
            AppInfo(bundleID: "c", name: "zed"),
            AppInfo(bundleID: "a", name: "App 10"),
            AppInfo(bundleID: "b", name: "App 9"),
        ]
        #expect(AppInfo.sortedUnique(apps, excluding: []).map(\.bundleID) == ["b", "a", "c"])
    }

    /// Two running copies of one app appear once, and apps already ignored aren't offered again.
    @Test func dropsDuplicatesAndExcludedApps() {
        let apps = [
            AppInfo(bundleID: "com.apple.Safari", name: "Safari"),
            AppInfo(bundleID: "com.apple.Safari", name: "Safari"),
            AppInfo(bundleID: "com.apple.Notes", name: "Notes"),
        ]
        let offered = AppInfo.sortedUnique(apps, excluding: ["com.apple.Notes"])
        #expect(offered.map(\.bundleID) == ["com.apple.Safari"])
    }

    @Test func anUninstalledAppShowsItsBundleID() {
        #expect(AppInfo(bundleID: "io.example.not-installed").name == "io.example.not-installed")
    }
}
