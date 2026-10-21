import KeyboardShortcuts
import MullionCore
import Testing
@testable import Mullion

@MainActor
struct ShortcutConflictsTests {
    private static let defaults: (WindowAction) -> KeyboardShortcuts.Shortcut? = { DefaultShortcuts.shortcuts[$0] }

    @Test func findsTheActionWithTheShortcut() throws {
        let leftHalf = try #require(DefaultShortcuts.shortcuts[.leftHalf])
        let other = ShortcutConflicts.action(using: leftHalf, except: .center, shortcutFor: Self.defaults)
        #expect(other == .leftHalf)
    }

    /// Re-recording an action's own shortcut is not a conflict.
    @Test func ignoresTheActionItself() throws {
        let leftHalf = try #require(DefaultShortcuts.shortcuts[.leftHalf])
        #expect(ShortcutConflicts.action(using: leftHalf, except: .leftHalf, shortcutFor: Self.defaults) == nil)
    }

    @Test func aFreeShortcutHasNoConflict() {
        let free = KeyboardShortcuts.Shortcut(.z, modifiers: [.control, .option])
        #expect(ShortcutConflicts.action(using: free, except: .center, shortcutFor: Self.defaults) == nil)
    }

    /// The defaults themselves never clash (SHORTCUTS.md).
    @Test func theDefaultsAreUnique() {
        let assigned = DefaultShortcuts.shortcuts.values
        #expect(Set(assigned).count == assigned.count)
    }
}
