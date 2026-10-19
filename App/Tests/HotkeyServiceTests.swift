import KeyboardShortcuts
import Testing
@testable import Mullion

/// Serialized: `KeyboardShortcuts.isEnabled` is global state.
@MainActor
@Suite(.serialized)
struct HotkeyServiceTests {
    /// Regression: hotkeys stayed registered while Accessibility was revoked, so ⌃⌥← was swallowed
    /// and never reached the frontmost app (PRD §6.9.3).
    @Test func disablingReleasesEveryHotkeyAndEnablingRestoresThem() {
        let service = HotkeyService { _ in }
        defer { KeyboardShortcuts.isEnabled = true }

        service.setEnabled(false)
        #expect(KeyboardShortcuts.isEnabled == false)

        service.setEnabled(true)
        #expect(KeyboardShortcuts.isEnabled == true)
    }
}
