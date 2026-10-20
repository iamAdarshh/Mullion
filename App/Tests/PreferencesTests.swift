import Foundation
import Testing
@testable import Mullion

@MainActor
struct PreferencesTests {
    /// A throwaway defaults suite, so tests never touch the real preferences.
    private static func makePreferences() throws -> Preferences {
        let suite = "PreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return Preferences(defaults: defaults)
    }

    @Test func nothingIsIgnoredByDefault() throws {
        #expect(try Self.makePreferences().ignoredBundleIDs.isEmpty)
    }

    @Test func ignoringAnAppAndTakingItOffAgain() throws {
        let preferences = try Self.makePreferences()
        preferences.setIgnored(true, bundleID: "com.apple.Safari")
        preferences.setIgnored(true, bundleID: "com.apple.Notes")
        #expect(preferences.ignoredBundleIDs == ["com.apple.Safari", "com.apple.Notes"])
        preferences.setIgnored(false, bundleID: "com.apple.Safari")
        #expect(preferences.ignoredBundleIDs == ["com.apple.Notes"])
    }

    @Test func ignoringTwiceKeepsOneEntry() throws {
        let preferences = try Self.makePreferences()
        preferences.setIgnored(true, bundleID: "com.apple.Safari")
        preferences.setIgnored(true, bundleID: "com.apple.Safari")
        #expect(preferences.ignoredBundleIDs == ["com.apple.Safari"])
    }

    @Test func dragAwayRestoresTheSizeByDefault() throws {
        let preferences = try Self.makePreferences()
        #expect(preferences.restoresSizeOnDragAway)
        preferences.restoresSizeOnDragAway = false
        #expect(!preferences.restoresSizeOnDragAway)
    }
}
