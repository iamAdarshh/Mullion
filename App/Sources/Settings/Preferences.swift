import Foundation
import MullionCore

/// Typed access to Mullion's scalar preferences in `UserDefaults` (ARCHITECTURE §8).
/// The Settings window that edits these arrives in M3; until then the defaults apply.
@MainActor
final class Preferences {
    private enum Key {
        static let gap = "gap"
        static let almostMaximizePercent = "almostMaximizePercent"
        static let resizeStep = "resizeStep"
        static let repeatBehavior = "repeatBehavior"
        static let ignoredBundleIDs = "ignoredBundleIDs"
        static let restoresSizeOnDragAway = "restoresSizeOnDragAway"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = ActionSettings.defaults
        defaults.register(defaults: [
            Key.gap: Double(fallback.gap),
            Key.almostMaximizePercent: Int((fallback.almostMaximizeFraction * 100).rounded()),
            Key.resizeStep: Double(fallback.resizeStep),
            Key.repeatBehavior: fallback.repeatBehavior.rawValue,
            Key.restoresSizeOnDragAway: true,
        ])
    }

    /// The settings every action uses. Out-of-range stored values are clamped by `ActionSettings`.
    var actionSettings: ActionSettings {
        get {
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
            defaults.set(Double(newValue.gap), forKey: Key.gap)
            defaults.set(Int((newValue.almostMaximizeFraction * 100).rounded()), forKey: Key.almostMaximizePercent)
            defaults.set(Double(newValue.resizeStep), forKey: Key.resizeStep)
            defaults.set(newValue.repeatBehavior.rawValue, forKey: Key.repeatBehavior)
        }
    }

    /// Whether a snapped window dragged away and dropped outside every snap area gets its size from
    /// before the snap back (PRD §6.3, §6.8 General).
    var restoresSizeOnDragAway: Bool {
        get { defaults.bool(forKey: Key.restoresSizeOnDragAway) }
        set { defaults.set(newValue, forKey: Key.restoresSizeOnDragAway) }
    }

    /// Apps whose windows never snap when dragged, by bundle ID (PRD §6.4). Shortcuts and the menu
    /// still act on them: those are a deliberate request for the frontmost window.
    var ignoredBundleIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.ignoredBundleIDs) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: Key.ignoredBundleIDs) }
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
