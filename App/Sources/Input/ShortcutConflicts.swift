import KeyboardShortcuts
import MullionCore

/// Finds the Mullion action that already uses a shortcut, so one key combination never triggers two
/// actions (PRD §6.8 Shortcuts). Clashes with macOS and menu shortcuts are the recorder's own job.
@MainActor
enum ShortcutConflicts {
    /// The first other action (in menu order) whose shortcut is `shortcut`, or `nil`.
    static func action(
        using shortcut: KeyboardShortcuts.Shortcut,
        except action: WindowAction,
        shortcutFor: (WindowAction) -> KeyboardShortcuts.Shortcut? = { DefaultShortcuts.name(for: $0).shortcut }
    ) -> WindowAction? {
        WindowAction.allCases.first { $0 != action && shortcutFor($0) == shortcut }
    }

    /// Validation for the recorder of `action`'s shortcut.
    static func validate(
        _ shortcut: KeyboardShortcuts.Shortcut,
        for action: WindowAction
    ) -> KeyboardShortcuts.ValidationResult {
        guard let other = Self.action(using: shortcut, except: action) else { return .allow }
        return .disallow(reason: String(
            localized: "This shortcut is already used by “\(other.title)”.",
            comment: "Recording a shortcut another Mullion action has. The name is an action, such as Left Half."
        ))
    }

    private static let functionKeys: Set<KeyboardShortcuts.Key> = [
        .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
        .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20,
    ]

    /// Whether the recorder would accept `shortcut`, for shortcuts that come from elsewhere (an
    /// imported file): a valid key with ⌘, ⌥ or ⌃, or a function key, and not one macOS uses. A
    /// global hotkey on a bare key would swallow that key in every app.
    static func isAllowed(_ shortcut: MullionConfig.Shortcut) -> Bool {
        guard (0 ... 0x7F).contains(shortcut.keyCode) else { return false }
        let candidate = KeyboardShortcuts.Shortcut(carbonKeyCode: shortcut.keyCode, carbonModifiers: shortcut.modifiers)
        let hasModifier = !candidate.modifiers.isDisjoint(with: [.command, .option, .control])
        let isFunctionKey = candidate.key.map(functionKeys.contains) ?? false
        return (hasModifier || isFunctionKey) && !candidate.isTakenBySystem
    }
}
