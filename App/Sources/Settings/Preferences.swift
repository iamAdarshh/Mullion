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
}
