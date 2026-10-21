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

    /// Missing actions get their default. A shortcut an earlier action already took is skipped, so
    /// one key combination never triggers two actions.
    private static func apply(_ config: [String: MullionConfig.Shortcut?], to shortcuts: any ShortcutStoring) {
        var taken: [MullionConfig.Shortcut] = []
        for action in WindowAction.allCases {
            guard let entry = config[action.rawValue] else {
                shortcuts.reset(action)
                continue
            }
            if let shortcut = entry, taken.contains(shortcut) {
                Log.settings.notice("Imported shortcut for \(action.rawValue, privacy: .public) is taken; cleared")
                shortcuts.setShortcut(nil, for: action)
                continue
            }
            if let shortcut = entry {
                taken.append(shortcut)
            }
            shortcuts.setShortcut(entry, for: action)
        }
    }
}
