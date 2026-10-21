import MullionCore
@testable import Mullion

/// Shortcuts in memory, starting from the defaults in SHORTCUTS.md.
@MainActor
final class FakeShortcutStore: ShortcutStoring {
    private(set) var shortcuts: [WindowAction: MullionConfig.Shortcut] = FakeShortcutStore.defaults

    static let defaults: [WindowAction: MullionConfig.Shortcut] = DefaultShortcuts.shortcuts.mapValues {
        MullionConfig.Shortcut(keyCode: $0.carbonKeyCode, modifiers: $0.carbonModifiers)
    }

    func shortcut(for action: WindowAction) -> MullionConfig.Shortcut? {
        shortcuts[action]
    }

    func setShortcut(_ shortcut: MullionConfig.Shortcut?, for action: WindowAction) {
        shortcuts[action] = shortcut
    }

    func reset(_ action: WindowAction) {
        shortcuts[action] = Self.defaults[action]
    }
}
