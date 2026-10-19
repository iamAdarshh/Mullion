import CoreGraphics

/// The size steps of repeat-to-cycle for half actions (PRD §6.2): ½ → ⅔ → ⅓ → ½.
public enum CycleState {
    /// The steps in order. The first is the size a half action starts with.
    public static let fractions: [CGFloat] = [1.0 / 2, 2.0 / 3, 1.0 / 3]

    /// The step after `current`. `nil` (a fresh half) or an unknown value counts as ½.
    public static func next(after current: CGFloat?) -> CGFloat {
        let index = current.flatMap { value in fractions.firstIndex { abs($0 - value) < 0.0001 } } ?? 0
        return fractions[(index + 1) % fractions.count]
    }
}
