import KeyboardShortcuts
import MullionCore

/// Reads and writes the action shortcuts, so config export and import can be tested with a fake.
@MainActor
protocol ShortcutStoring {
    /// The action's shortcut, or `nil` if the user cleared it.
    func shortcut(for action: WindowAction) -> MullionConfig.Shortcut?
    /// Sets the shortcut; `nil` clears it.
    func setShortcut(_ shortcut: MullionConfig.Shortcut?, for action: WindowAction)
    /// Puts the action's default shortcut back (SHORTCUTS.md).
    func reset(_ action: WindowAction)
}

/// The shortcuts as the KeyboardShortcuts package stores them in `UserDefaults`.
@MainActor
struct ShortcutStore: ShortcutStoring {
    func shortcut(for action: WindowAction) -> MullionConfig.Shortcut? {
        KeyboardShortcuts.getShortcut(for: DefaultShortcuts.name(for: action)).map {
            MullionConfig.Shortcut(keyCode: $0.carbonKeyCode, modifiers: $0.carbonModifiers)
        }
    }

    func setShortcut(_ shortcut: MullionConfig.Shortcut?, for action: WindowAction) {
        KeyboardShortcuts.setShortcut(
            shortcut.map { KeyboardShortcuts.Shortcut(carbonKeyCode: $0.keyCode, carbonModifiers: $0.modifiers) },
            for: DefaultShortcuts.name(for: action)
        )
    }

    func reset(_ action: WindowAction) {
        KeyboardShortcuts.reset(DefaultShortcuts.name(for: action))
    }
}
