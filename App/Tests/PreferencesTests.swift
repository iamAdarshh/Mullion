import Foundation
import MullionCore
import Observation
import os
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

    /// The values live in `UserDefaults`, so observation only works if every accessor reports itself.
    @Test(arguments: [
        { (prefs: Preferences) in prefs.actionSettings.gap = 12 },
        { (prefs: Preferences) in prefs.restoresSizeOnDragAway = false },
        { (prefs: Preferences) in prefs.hidesTilingNotice = true },
        { (prefs: Preferences) in prefs.setIgnored(true, bundleID: "com.apple.Safari") },
    ] as [@MainActor @Sendable (Preferences) -> Void])
    func changesAreObservable(change: @MainActor @Sendable (Preferences) -> Void) {
        // `onChange` is `@Sendable`, so the flag needs a lock even though it runs on this thread.
        let changed = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = preferences.actionSettings
            _ = preferences.restoresSizeOnDragAway
            _ = preferences.hidesTilingNotice
            _ = preferences.ignoredBundleIDs
        } onChange: {
            changed.withLock { $0 = true }
        }
        change(preferences)
        #expect(changed.withLock { $0 })
    }

    @Test func actionSettingsRoundTrip() {
        preferences.actionSettings.gap = 12
        preferences.actionSettings.almostMaximizeFraction = 0.8
        preferences.actionSettings.resizeStep = 50
        preferences.actionSettings.repeatBehavior = .moveToNextDisplay
        #expect(preferences.actionSettings == ActionSettings(
            gap: 12, almostMaximizeFraction: 0.8, resizeStep: 50, repeatBehavior: .moveToNextDisplay
        ))
    }
}
