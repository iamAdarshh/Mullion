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
}
