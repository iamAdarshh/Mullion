import Foundation
import MullionCore
import Testing
@testable import Mullion

/// Same setup as `PreferencesTests`, on a suite of its own.
@Suite(.serialized)
@MainActor
final class ConfigTransferTests {
    private nonisolated static let suite = "io.github.iamadarshh.mullion.tests.config"
    private nonisolated static let freshSuite = suite + ".fresh"
    private let defaults: UserDefaults
    private let preferences: Preferences
    private let shortcuts = FakeShortcutStore()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: Self.suite))
        defaults.removePersistentDomain(forName: Self.suite)
        preferences = Preferences(defaults: defaults)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: Self.suite)
        UserDefaults.standard.removePersistentDomain(forName: Self.freshSuite)
    }

    private static let customShortcut = MullionConfig.Shortcut(keyCode: 7, modifiers: 6144)

    private func customise() throws {
        preferences.actionSettings = ActionSettings(
            gap: 12, almostMaximizeFraction: 0.8, resizeStep: 50, repeatBehavior: .doNothing
        )
        preferences.showsMenuBarIcon = false
        preferences.restoresSizeOnDragAway = false
        preferences.dragToSnapEnabled = false
        preferences.snapModifier = .control
        preferences.dragSettings = DragSettings(edgeThickness: 10, cornerSize: 40)
        preferences.previewStyle = try PreviewStyle(color: #require(HexColor.color(from: "#FF8800")), opacity: 0.4)
        preferences.hapticFeedback = false
        preferences.hidesTilingNotice = true
        preferences.ignoredBundleIDs = ["com.apple.Notes"]
        shortcuts.setShortcut(Self.customShortcut, for: .center)
        shortcuts.setShortcut(nil, for: .leftHalf)
    }

    @Test func exportThenImportRestoresEverything() throws {
        try customise()
        let exported = ConfigTransfer.export(preferences: preferences, shortcuts: shortcuts)
        let file = try MullionConfig.decode(exported.encoded())

        ConfigTransfer.resetAll(preferences: preferences, shortcuts: shortcuts)
        ConfigTransfer.apply(file, to: preferences, shortcuts: shortcuts)

        #expect(ConfigTransfer.export(preferences: preferences, shortcuts: shortcuts) == exported)
        #expect(shortcuts.shortcut(for: .center) == Self.customShortcut)
        #expect(shortcuts.shortcut(for: .leftHalf) == nil)
    }

    /// Import replaces everything: what the file leaves out goes back to its default.
    @Test func aMinimalFileResetsEverything() throws {
        try customise()
        ConfigTransfer.apply(MullionConfig(), to: preferences, shortcuts: shortcuts)
        let fresh = try freshPreferences()
        #expect(ConfigTransfer.export(preferences: preferences, shortcuts: shortcuts)
            == ConfigTransfer.export(preferences: fresh, shortcuts: FakeShortcutStore()))
    }

    @Test func outOfRangeAndUnknownValuesAreClampedOrSkipped() {
        let config = MullionConfig(
            general: .init(gap: 500, almostMaximizePercent: 10, resizeStep: -5),
            drag: .init(
                snapModifier: "shift",
                edgeThickness: 80,
                cornerSize: 2,
                previewColor: "orange",
                previewOpacity: 5
            )
        )
        ConfigTransfer.apply(config, to: preferences, shortcuts: shortcuts)
        #expect(preferences.actionSettings.gap == 40)
        #expect(preferences.actionSettings.almostMaximizeFraction == 0.5)
        #expect(preferences.actionSettings.resizeStep == 1)
        #expect(preferences.snapModifier == .option)
        #expect(preferences.dragSettings == DragSettings(edgeThickness: 50, cornerSize: 50))
        #expect(preferences.previewStyle.color == nil)
        #expect(preferences.previewStyle.opacity == PreviewStyle.opacityRange.upperBound)
    }

    /// One key combination never triggers two actions: the later action in menu order loses it.
    @Test func aDuplicateShortcutIsCleared() {
        let config = MullionConfig(shortcuts: [
            WindowAction.leftHalf.rawValue: Self.customShortcut,
            WindowAction.center.rawValue: Self.customShortcut,
        ])
        ConfigTransfer.apply(config, to: preferences, shortcuts: shortcuts)
        #expect(shortcuts.shortcut(for: .leftHalf) == Self.customShortcut)
        #expect(shortcuts.shortcut(for: .center) == nil)
    }

    /// A partial file that takes ⌃⌥← for Center: Left Half, left out of the file, loses its default
    /// ⌃⌥← instead of sharing it.
    @Test func anImportedShortcutBeatsADefault() throws {
        let leftHalf = try #require(ConfigTransfer.defaultShortcuts[.leftHalf])
        ConfigTransfer.apply(
            MullionConfig(shortcuts: [WindowAction.center.rawValue: leftHalf]),
            to: preferences,
            shortcuts: shortcuts
        )
        #expect(shortcuts.shortcut(for: .center) == leftHalf)
        #expect(shortcuts.shortcut(for: .leftHalf) == nil)
        #expect(shortcuts.shortcut(for: .rightHalf) == ConfigTransfer.defaultShortcuts[.rightHalf])
    }

    /// A shortcut the recorder would refuse, such as a bare "a", is skipped: the action keeps its
    /// default instead of swallowing that key in every app.
    @Test func aRefusedShortcutKeepsTheDefault() {
        let bareA = MullionConfig.Shortcut(keyCode: 0, modifiers: 0)
        let resolved = ConfigTransfer.resolveShortcuts(
            [WindowAction.leftHalf.rawValue: bareA],
            defaults: ConfigTransfer.defaultShortcuts,
            isAllowed: { $0 != bareA }
        )
        #expect(resolved[.leftHalf] == .some(ConfigTransfer.defaultShortcuts[.leftHalf]))
    }

    @Test func resetAllMatchesAFreshStart() throws {
        try customise()
        ConfigTransfer.resetAll(preferences: preferences, shortcuts: shortcuts)
        #expect(shortcuts.shortcut(for: .center) == ConfigTransfer.defaultShortcuts[.center])
        let fresh = try freshPreferences()
        #expect(ConfigTransfer.export(preferences: preferences, shortcuts: shortcuts).general
            == ConfigTransfer.export(preferences: fresh, shortcuts: shortcuts).general)
        #expect(ConfigTransfer.export(preferences: preferences, shortcuts: shortcuts).drag
            == ConfigTransfer.export(preferences: fresh, shortcuts: shortcuts).drag)
        #expect(preferences.ignoredBundleIDs.isEmpty)
    }

    /// Preferences on an empty suite of their own, as on first launch.
    private func freshPreferences() throws -> Preferences {
        let empty = try #require(UserDefaults(suiteName: Self.freshSuite))
        empty.removePersistentDomain(forName: Self.freshSuite)
        return Preferences(defaults: empty)
    }
}
