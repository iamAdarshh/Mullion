import Foundation
import Testing
@testable import Mullion

/// Each test gets a fresh instance on one fixed, throwaway defaults suite, emptied before and after
/// every test, so tests never touch the real preferences. A fresh suite per test would leave one empty
/// plist per test in ~/Library/Preferences (the preferences daemon writes it even after the domain is
/// removed); a fixed name leaves at most one. Serialized, because every test shares that suite.
@Suite(.serialized)
@MainActor
final class PreferencesTests {
    private nonisolated static let suite = "io.github.iamadarshh.mullion.tests"
    private let preferences: Preferences

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suite))
        defaults.removePersistentDomain(forName: Self.suite)
        preferences = Preferences(defaults: defaults)
    }

    deinit {
        // Removing a domain by name works from any defaults object.
        UserDefaults.standard.removePersistentDomain(forName: Self.suite)
    }

    @Test func nothingIsIgnoredByDefault() {
        #expect(preferences.ignoredBundleIDs.isEmpty)
    }

    @Test func ignoringAnAppAndTakingItOffAgain() {
        preferences.setIgnored(true, bundleID: "com.apple.Safari")
        preferences.setIgnored(true, bundleID: "com.apple.Notes")
        #expect(preferences.ignoredBundleIDs == ["com.apple.Safari", "com.apple.Notes"])
        preferences.setIgnored(false, bundleID: "com.apple.Safari")
        #expect(preferences.ignoredBundleIDs == ["com.apple.Notes"])
    }

    @Test func ignoringTwiceKeepsOneEntry() {
        preferences.setIgnored(true, bundleID: "com.apple.Safari")
        preferences.setIgnored(true, bundleID: "com.apple.Safari")
        #expect(preferences.ignoredBundleIDs == ["com.apple.Safari"])
    }

    @Test func dragAwayRestoresTheSizeByDefault() {
        #expect(preferences.restoresSizeOnDragAway)
        preferences.restoresSizeOnDragAway = false
        #expect(!preferences.restoresSizeOnDragAway)
    }

    @Test func theTilingNoticeIsShownUntilHidden() {
        #expect(!preferences.hidesTilingNotice)
        preferences.hidesTilingNotice = true
        #expect(preferences.hidesTilingNotice)
    }
}
