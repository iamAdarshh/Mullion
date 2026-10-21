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

    @Test func theMenuBarIconIsShownByDefault() {
        #expect(preferences.showsMenuBarIcon)
        preferences.showsMenuBarIcon = false
        #expect(!preferences.showsMenuBarIcon)
    }

    @Test func dragDefaults() {
        #expect(preferences.dragToSnapEnabled)
        #expect(preferences.snapModifier == .option)
        #expect(preferences.dragSettings == .defaults)
        #expect(preferences.previewStyle == PreviewStyle())
        #expect(preferences.hapticFeedback)
    }

    @Test func dragSettingsRoundTrip() throws {
        preferences.dragToSnapEnabled = false
        preferences.snapModifier = .control
        preferences.dragSettings = DragSettings(edgeThickness: 12, cornerSize: 40)
        let orange = try #require(HexColor.color(from: "#FF8800"))
        preferences.previewStyle = PreviewStyle(color: orange, opacity: 0.35)
        preferences.hapticFeedback = false

        #expect(!preferences.dragToSnapEnabled)
        #expect(preferences.snapModifier == .control)
        #expect(preferences.dragSettings == DragSettings(edgeThickness: 12, cornerSize: 40))
        #expect(preferences.previewStyle.color.flatMap(HexColor.string(from:)) == "#FF8800")
        #expect(preferences.previewStyle.opacity == 0.35)
        #expect(!preferences.hapticFeedback)
    }

    @Test func goingBackToTheAccentColour() throws {
        preferences.previewStyle.color = try #require(HexColor.color(from: "#FF8800"))
        preferences.previewStyle.color = nil
        #expect(preferences.previewStyle.color == nil)
    }

    /// Values written by hand (`defaults write`) or by an older version are clamped on read.
    @Test func outOfRangeStoredValuesAreClamped() throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suite))
        defaults.set(0.95, forKey: "previewOpacity")
        defaults.set(500.0, forKey: "edgeThickness")
        defaults.set("shift", forKey: "snapModifier")
        #expect(preferences.previewStyle.opacity == PreviewStyle.opacityRange.upperBound)
        #expect(preferences.dragSettings.edgeThickness == 50)
        #expect(preferences.snapModifier == .option)
    }

    /// AppKit objects follow a preference through `keepApplying`, every time it changes.
    @Test func keepApplyingRunsAgainAfterEachChange() async {
        var seen: [Bool] = []
        keepApplying { [preferences] in seen.append(preferences.showsMenuBarIcon) }
        preferences.showsMenuBarIcon = false
        await Task.yield()
        preferences.showsMenuBarIcon = true
        await Task.yield()
        #expect(seen == [true, false, true])
    }

    /// The values live in `UserDefaults`, so observation only works if every accessor reports itself.
    @Test(arguments: [
        { (prefs: Preferences) in prefs.actionSettings.gap = 12 },
        { (prefs: Preferences) in prefs.restoresSizeOnDragAway = false },
        { (prefs: Preferences) in prefs.hidesTilingNotice = true },
        { (prefs: Preferences) in prefs.showsMenuBarIcon = false },
        { (prefs: Preferences) in prefs.dragToSnapEnabled = false },
        { (prefs: Preferences) in prefs.snapModifier = .control },
        { (prefs: Preferences) in prefs.dragSettings.edgeThickness = 10 },
        { (prefs: Preferences) in prefs.previewStyle.opacity = 0.4 },
        { (prefs: Preferences) in prefs.hapticFeedback = false },
        { (prefs: Preferences) in prefs.setIgnored(true, bundleID: "com.apple.Safari") },
    ] as [@MainActor @Sendable (Preferences) -> Void])
    func changesAreObservable(change: @MainActor @Sendable (Preferences) -> Void) {
        // `onChange` is `@Sendable`, so the flag needs a lock even though it runs on this thread.
        let changed = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = preferences.actionSettings
            _ = preferences.restoresSizeOnDragAway
            _ = preferences.hidesTilingNotice
            _ = preferences.showsMenuBarIcon
            _ = preferences.dragToSnapEnabled
            _ = preferences.snapModifier
            _ = preferences.dragSettings
            _ = preferences.previewStyle
            _ = preferences.hapticFeedback
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
