import CoreGraphics

/// User settings that change action geometry (PRD §6.1, §6.2, §6.8 General tab).
public struct ActionSettings: Equatable, Sendable {
    /// What a repeated half shortcut does (PRD §6.2).
    public enum RepeatBehavior: String, CaseIterable, Codable, Sendable {
        /// ½ → ⅔ → ⅓ → ½
        case cycleSizes
        case doNothing
        case moveToNextDisplay
    }

    /// Gap in points around tiled windows, 0…40.
    public var gap: CGFloat {
        didSet { gap = min(max(gap, 0), 40) }
    }

    /// Size of *Almost Maximize* as a fraction of the visible frame, 0.5…1.
    public var almostMaximizeFraction: CGFloat {
        didSet { almostMaximizeFraction = min(max(almostMaximizeFraction, 0.5), 1) }
    }

    /// Points added to or removed from each side by *Grow* / *Shrink*.
    public var resizeStep: CGFloat {
        didSet { resizeStep = max(resizeStep, 1) }
    }

    public var repeatBehavior: RepeatBehavior

    public init(
        gap: CGFloat = 0,
        almostMaximizeFraction: CGFloat = 0.9,
        resizeStep: CGFloat = 30,
        repeatBehavior: RepeatBehavior = .cycleSizes
    ) {
        self.gap = min(max(gap, 0), 40)
        self.almostMaximizeFraction = min(max(almostMaximizeFraction, 0.5), 1)
        self.resizeStep = max(resizeStep, 1)
        self.repeatBehavior = repeatBehavior
    }

    public static let defaults = ActionSettings()
}
