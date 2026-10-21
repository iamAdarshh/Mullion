import AppKit
import MullionCore
import Observation

/// Typed access to Mullion's scalar preferences in `UserDefaults` (ARCHITECTURE §8), edited in the
/// Settings window. Observable, so SwiftUI views update when a value changes. The values live in
/// `UserDefaults`, not in stored properties, so each one reports its reads (`access`) and writes
/// (`withMutation`) to the observation registrar itself.
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let gap = "gap"
        static let almostMaximizePercent = "almostMaximizePercent"
        static let resizeStep = "resizeStep"
        static let repeatBehavior = "repeatBehavior"
        static let ignoredBundleIDs = "ignoredBundleIDs"
        static let restoresSizeOnDragAway = "restoresSizeOnDragAway"
        static let hidesTilingNotice = "hidesTilingNotice"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let dragToSnap = "dragToSnap"
        static let snapModifier = "snapModifier"
        static let edgeThickness = "edgeThickness"
        static let cornerSize = "cornerSize"
        static let previewColor = "previewColor"
        static let previewOpacity = "previewOpacity"
        static let hapticFeedback = "hapticFeedback"
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = ActionSettings.defaults
        let drag = DragSettings.defaults
        defaults.register(defaults: [
            Key.gap: Double(fallback.gap),
            Key.almostMaximizePercent: Int((fallback.almostMaximizeFraction * 100).rounded()),
            Key.resizeStep: Double(fallback.resizeStep),
            Key.repeatBehavior: fallback.repeatBehavior.rawValue,
            Key.restoresSizeOnDragAway: true,
            Key.showsMenuBarIcon: true,
            Key.dragToSnap: true,
            Key.snapModifier: SnapModifier.option.rawValue,
            Key.edgeThickness: Double(drag.edgeThickness),
            Key.cornerSize: Double(drag.cornerSize),
            Key.previewOpacity: PreviewStyle.defaultOpacity,
            Key.hapticFeedback: true,
        ])
    }

    /// The settings every action uses. Out-of-range stored values are clamped by `ActionSettings`.
    var actionSettings: ActionSettings {
        get {
            access(keyPath: \.actionSettings)
            let behavior = defaults.string(forKey: Key.repeatBehavior)
                .flatMap(ActionSettings.RepeatBehavior.init(rawValue:)) ?? ActionSettings.defaults.repeatBehavior
            return ActionSettings(
                gap: defaults.double(forKey: Key.gap),
                almostMaximizeFraction: CGFloat(defaults.integer(forKey: Key.almostMaximizePercent)) / 100,
                resizeStep: defaults.double(forKey: Key.resizeStep),
                repeatBehavior: behavior
            )
        }
        set {
            withMutation(keyPath: \.actionSettings) {
                defaults.set(Double(newValue.gap), forKey: Key.gap)
                defaults.set(Int((newValue.almostMaximizeFraction * 100).rounded()), forKey: Key.almostMaximizePercent)
                defaults.set(Double(newValue.resizeStep), forKey: Key.resizeStep)
                defaults.set(newValue.repeatBehavior.rawValue, forKey: Key.repeatBehavior)
            }
        }
    }

    /// Whether a snapped window dragged away and dropped outside every snap area gets its size from
    /// before the snap back (PRD §6.3, §6.8 General).
    var restoresSizeOnDragAway: Bool {
        get {
            access(keyPath: \.restoresSizeOnDragAway)
            return defaults.bool(forKey: Key.restoresSizeOnDragAway)
        }
        set { withMutation(keyPath: \.restoresSizeOnDragAway) { defaults.set(
            newValue,
            forKey: Key.restoresSizeOnDragAway
        ) } }
    }

    /// Whether Mullion's icon is in the menu bar (PRD §6.7). When it's hidden, opening Mullion again
    /// opens Settings.
    var showsMenuBarIcon: Bool {
        get {
            access(keyPath: \.showsMenuBarIcon)
            return defaults.bool(forKey: Key.showsMenuBarIcon)
        }
        set { withMutation(keyPath: \.showsMenuBarIcon) { defaults.set(newValue, forKey: Key.showsMenuBarIcon) } }
    }

    /// Whether dragging a window to a screen edge snaps it (PRD §6.4, §6.8 Drag).
    var dragToSnapEnabled: Bool {
        get {
            access(keyPath: \.dragToSnapEnabled)
            return defaults.bool(forKey: Key.dragToSnap)
        }
        set { withMutation(keyPath: \.dragToSnapEnabled) { defaults.set(newValue, forKey: Key.dragToSnap) } }
    }

    /// The key that turns snapping off while held during a drag.
    var snapModifier: SnapModifier {
        get {
            access(keyPath: \.snapModifier)
            return defaults.string(forKey: Key.snapModifier).flatMap(SnapModifier.init(rawValue:)) ?? .option
        }
        set { withMutation(keyPath: \.snapModifier) { defaults.set(newValue.rawValue, forKey: Key.snapModifier) } }
    }

    /// The size of the snap areas. Out-of-range stored values are clamped by `DragSettings`.
    var dragSettings: DragSettings {
        get {
            access(keyPath: \.dragSettings)
            return DragSettings(
                edgeThickness: defaults.double(forKey: Key.edgeThickness),
                cornerSize: defaults.double(forKey: Key.cornerSize)
            )
        }
        set {
            withMutation(keyPath: \.dragSettings) {
                defaults.set(Double(newValue.edgeThickness), forKey: Key.edgeThickness)
                defaults.set(Double(newValue.cornerSize), forKey: Key.cornerSize)
            }
        }
    }

    /// The preview's colour and opacity. No stored colour means the system accent colour.
    var previewStyle: PreviewStyle {
        get {
            access(keyPath: \.previewStyle)
            let opacity = defaults.double(forKey: Key.previewOpacity)
            return PreviewStyle(
                color: defaults.string(forKey: Key.previewColor).flatMap(HexColor.color(from:)),
                opacity: min(max(opacity, PreviewStyle.opacityRange.lowerBound), PreviewStyle.opacityRange.upperBound)
            )
        }
        set {
            withMutation(keyPath: \.previewStyle) {
                defaults.set(newValue.color.flatMap(HexColor.string(from:)), forKey: Key.previewColor)
                defaults.set(newValue.opacity, forKey: Key.previewOpacity)
            }
        }
    }

    /// A light tap on Force Touch trackpads when the cursor enters a snap area.
    var hapticFeedback: Bool {
        get {
            access(keyPath: \.hapticFeedback)
            return defaults.bool(forKey: Key.hapticFeedback)
        }
        set { withMutation(keyPath: \.hapticFeedback) { defaults.set(newValue, forKey: Key.hapticFeedback) } }
    }

    /// The macOS tiling settings that clash with these preferences (PRD §6.6).
    func relevantTilingConflicts(_ conflicts: SystemTilingCheck.Conflicts) -> SystemTilingCheck.Conflicts {
        conflicts.relevant(dragToSnap: dragToSnapEnabled, snapModifier: snapModifier)
    }

    /// Whether Mullion needs to follow window drags: to snap them, or to give a snapped window its
    /// size back when it's dragged away, which also works with drag to snap off (PRD §6.3).
    var watchesDrags: Bool {
        dragToSnapEnabled || restoresSizeOnDragAway
    }

    /// Whether the menu bar icon is shown. While Accessibility access is missing it always is, so
    /// its warning and *Grant Accessibility access…* item can't be hidden (PRD §6.9.3).
    func showsMenuBarIcon(isTrusted: Bool) -> Bool {
        showsMenuBarIcon || !isTrusted
    }

    /// Whether the user chose *Don't Show Again* on the macOS tiling notice (PRD §6.6).
    var hidesTilingNotice: Bool {
        get {
            access(keyPath: \.hidesTilingNotice)
            return defaults.bool(forKey: Key.hidesTilingNotice)
        }
        set { withMutation(keyPath: \.hidesTilingNotice) { defaults.set(newValue, forKey: Key.hidesTilingNotice) } }
    }

    /// Apps whose windows never snap when dragged, by bundle ID (PRD §6.4). Shortcuts and the menu
    /// still act on them: those are a deliberate request for the frontmost window.
    var ignoredBundleIDs: Set<String> {
        get {
            access(keyPath: \.ignoredBundleIDs)
            return Set(defaults.stringArray(forKey: Key.ignoredBundleIDs) ?? [])
        }
        set {
            withMutation(keyPath: \.ignoredBundleIDs) { defaults.set(newValue.sorted(), forKey: Key.ignoredBundleIDs) }
        }
    }

    /// Adds the app to the ignore list, or takes it off.
    func setIgnored(_ ignored: Bool, bundleID: String) {
        if ignored {
            ignoredBundleIDs.insert(bundleID)
        } else {
            ignoredBundleIDs.remove(bundleID)
        }
    }
}
