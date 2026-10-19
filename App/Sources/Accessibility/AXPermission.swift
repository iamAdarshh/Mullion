import AppKit
import ApplicationServices

/// Live Accessibility trust checks.
///
/// These are process-level calls (no IPC to another app), so unlike window reads and writes
/// they are cheap and safe on the main actor; they don't need `AXQueue`.
@MainActor
struct AXPermission: AccessibilityTrustChecking {
    /// The value of `kAXTrustedCheckOptionPrompt`. The imported global is a mutable C var,
    /// which Swift 6 rejects as not concurrency-safe, so we use its documented string value.
    private static let promptOptionKey = "AXTrustedCheckOptionPrompt"

    private static let settingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func promptForTrust() -> Bool {
        let options = [Self.promptOptionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings at *Privacy & Security → Accessibility*.
    static func openSystemSettings() {
        guard let url = URL(string: settingsURL) else {
            Log.ax.error("Invalid Accessibility settings URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
