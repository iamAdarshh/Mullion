import AppKit
import KeyboardShortcuts
import MullionCore

/// The default shortcuts from `docs/SHORTCUTS.md`. Keep the two in sync.
///
/// All defaults use ⌃⌥, which macOS and common apps leave free. Sixths are deliberately unassigned.
enum DefaultShortcuts {
    private static let controlOption: NSEvent.ModifierFlags = [.control, .option]
    private static let controlOptionShift: NSEvent.ModifierFlags = [.control, .option, .shift]
    private static let controlOptionCommand: NSEvent.ModifierFlags = [.control, .option, .command]

    static let shortcuts: [WindowAction: KeyboardShortcuts.Shortcut] = [
        .leftHalf: .init(.leftArrow, modifiers: controlOption),
        .rightHalf: .init(.rightArrow, modifiers: controlOption),
        .topHalf: .init(.upArrow, modifiers: controlOption),
        .bottomHalf: .init(.downArrow, modifiers: controlOption),
        .topLeft: .init(.u, modifiers: controlOption),
        .topRight: .init(.i, modifiers: controlOption),
        .bottomLeft: .init(.j, modifiers: controlOption),
        .bottomRight: .init(.k, modifiers: controlOption),
        .firstThird: .init(.d, modifiers: controlOption),
        .centerThird: .init(.f, modifiers: controlOption),
        .lastThird: .init(.g, modifiers: controlOption),
        .firstTwoThirds: .init(.e, modifiers: controlOption),
        .lastTwoThirds: .init(.t, modifiers: controlOption),
        .maximize: .init(.return, modifiers: controlOption),
        .almostMaximize: .init(.return, modifiers: controlOptionShift),
        .maximizeHeight: .init(.upArrow, modifiers: controlOptionShift),
        .center: .init(.c, modifiers: controlOption),
        .restore: .init(.delete, modifiers: controlOption),
        .larger: .init(.equal, modifiers: controlOption),
        .smaller: .init(.minus, modifiers: controlOption),
        .nextDisplay: .init(.rightArrow, modifiers: controlOptionCommand),
        .previousDisplay: .init(.leftArrow, modifiers: controlOptionCommand),
    ]

    /// One shortcut name per action. The name is the action's raw value, which KeyboardShortcuts
    /// persists in `UserDefaults`, so it must never change.
    static let names: [WindowAction: KeyboardShortcuts.Name] = Dictionary(
        uniqueKeysWithValues: WindowAction.allCases.map { action in
            (action, KeyboardShortcuts.Name(action.rawValue, initial: shortcuts[action]))
        }
    )

    static func name(for action: WindowAction) -> KeyboardShortcuts.Name {
        names[action] ?? KeyboardShortcuts.Name(action.rawValue)
    }
}
