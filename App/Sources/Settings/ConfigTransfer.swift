import AppKit
import MullionCore

/// Turns Mullion's settings into a `MullionConfig` for *Export Settings…*, and applies one for
/// *Import Settings…* (PRD §6.8 Advanced). Launch at login isn't included: macOS owns it.
@MainActor
enum ConfigTransfer {
    /// Everything the user can change in Settings, every value written out.
    static func export(preferences: Preferences, shortcuts: any ShortcutStoring) -> MullionConfig {
        let actions = preferences.actionSettings
        let drag = preferences.dragSettings
        let style = preferences.previewStyle
        return MullionConfig(
            general: .init(
                showsMenuBarIcon: preferences.showsMenuBarIcon,
                repeatBehavior: actions.repeatBehavior,
                gap: Double(actions.gap),
                almostMaximizePercent: Int((actions.almostMaximizeFraction * 100).rounded()),
                resizeStep: Double(actions.resizeStep),
                restoresSizeOnDragAway: preferences.restoresSizeOnDragAway
            ),
            drag: .init(
                enabled: preferences.dragToSnapEnabled,
                snapModifier: preferences.snapModifier.rawValue,
                edgeThickness: Double(drag.edgeThickness),
                cornerSize: Double(drag.cornerSize),
                previewColor: style.color.flatMap(HexColor.string(from:)),
                previewOpacity: style.opacity,
                hapticFeedback: preferences.hapticFeedback,
                hidesTilingNotice: preferences.hidesTilingNotice
            ),
            shortcuts: Dictionary(uniqueKeysWithValues: WindowAction.allCases.map {
                ($0.rawValue, shortcuts.shortcut(for: $0))
            }),
            ignoredBundleIDs: preferences.ignoredBundleIDs.sorted()
        )
    }

    /// Replaces every setting: what `config` leaves out gets its default. Out-of-range values are
    /// clamped by the same types that clamp stored preferences; unknown values are skipped.
    static func apply(_ config: MullionConfig, to preferences: Preferences, shortcuts: any ShortcutStoring) {
        preferences.resetAll()
        apply(config.general, to: preferences)
        apply(config.drag, to: preferences)
        preferences.ignoredBundleIDs = Set(config.ignoredBundleIDs ?? [])
        apply(config.shortcuts, to: shortcuts)
    }

    private static func apply(_ general: MullionConfig.General, to preferences: Preferences) {
        var actions = preferences.actionSettings
        if let value = general.repeatBehavior {
            actions.repeatBehavior = value
        }
        if let value = general.gap {
            actions.gap = value
        }
        if let value = general.almostMaximizePercent {
            actions.almostMaximizeFraction = CGFloat(value) / 100
        }
        if let value = general.resizeStep {
            actions.resizeStep = value
        }
        preferences.actionSettings = actions
        if let value = general.showsMenuBarIcon {
            preferences.showsMenuBarIcon = value
        }
        if let value = general.restoresSizeOnDragAway {
            preferences.restoresSizeOnDragAway = value
        }
    }

    private static func apply(_ drag: MullionConfig.Drag, to preferences: Preferences) {
        if let value = drag.enabled {
            preferences.dragToSnapEnabled = value
        }
        if let value = drag.snapModifier.flatMap(SnapModifier.init(rawValue:)) {
            preferences.snapModifier = value
        }
        var sizes = preferences.dragSettings
        // Both at once: each is clamped against the other.
        sizes = DragSettings(
            edgeThickness: drag.edgeThickness ?? sizes.edgeThickness,
            cornerSize: drag.cornerSize ?? sizes.cornerSize
        )
        preferences.dragSettings = sizes
        var style = preferences.previewStyle
        style.color = drag.previewColor.flatMap(HexColor.color(from:))
        if let value = drag.previewOpacity {
            style.opacity = min(max(value, PreviewStyle.opacityRange.lowerBound), PreviewStyle.opacityRange.upperBound)
        }
        preferences.previewStyle = style
        if let value = drag.hapticFeedback {
            preferences.hapticFeedback = value
        }
        if let value = drag.hidesTilingNotice {
            preferences.hidesTilingNotice = value
        }
    }

    private static func apply(_ config: [String: MullionConfig.Shortcut?], to shortcuts: any ShortcutStoring) {
        let resolved = resolveShortcuts(config, defaults: defaultShortcuts, isAllowed: ShortcutConflicts.isAllowed)
        for action in WindowAction.allCases {
            shortcuts.setShortcut(resolved[action] ?? nil, for: action)
        }
    }

    /// The default shortcuts (SHORTCUTS.md) in the config's form.
    static let defaultShortcuts: [WindowAction: MullionConfig.Shortcut] = DefaultShortcuts.shortcuts.mapValues {
        MullionConfig.Shortcut(keyCode: $0.carbonKeyCode, modifiers: $0.carbonModifiers)
    }

    /// Every action's shortcut after importing `entries`: the file's own, or the default for an
    /// action the file leaves out. One key combination never triggers two actions: the file's
    /// shortcuts win over defaults, and between two of the file's, the first in menu order wins; the
    /// loser is cleared. A shortcut `isAllowed` refuses is skipped, as if the file left it out.
    static func resolveShortcuts(
        _ entries: [String: MullionConfig.Shortcut?],
        defaults: [WindowAction: MullionConfig.Shortcut],
        isAllowed: (MullionConfig.Shortcut) -> Bool
    ) -> [WindowAction: MullionConfig.Shortcut?] {
        var explicit: [WindowAction: MullionConfig.Shortcut?] = [:]
        for action in WindowAction.allCases {
            guard let entry = entries[action.rawValue] else { continue }
            if let shortcut = entry, !isAllowed(shortcut) {
                Log.settings.notice("Imported shortcut for \(action.rawValue, privacy: .public) isn't allowed; skipped")
                continue
            }
            explicit[action] = entry
        }

        var taken = Set<MullionConfig.Shortcut>()
        var resolved: [WindowAction: MullionConfig.Shortcut?] = [:]
        for action in WindowAction.allCases {
            guard let entry = explicit[action] else { continue }
            if let shortcut = entry, !taken.insert(shortcut).inserted {
                Log.settings.notice("Imported shortcut for \(action.rawValue, privacy: .public) is taken; cleared")
                resolved[action] = .some(nil)
            } else {
                resolved[action] = entry
            }
        }
        for action in WindowAction.allCases where explicit[action] == nil {
            let fallback = defaults[action]
            if let fallback, taken.contains(fallback) {
                Log.settings
                    .notice("Default shortcut for \(action.rawValue, privacy: .public) is imported elsewhere; cleared")
                resolved[action] = .some(nil)
            } else {
                resolved[action] = .some(fallback)
            }
        }
        return resolved
    }

    /// *Reset Everything…*: every preference, shortcut and ignored app back to its default. Launch at
    /// login is left alone: macOS owns it.
    static func resetAll(preferences: Preferences, shortcuts: any ShortcutStoring) {
        preferences.resetAll()
        for action in WindowAction.allCases {
            shortcuts.reset(action)
        }
    }
}
