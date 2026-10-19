/// The process-wide Accessibility trust check, behind a protocol so tests can fake it.
@MainActor
protocol AccessibilityTrustChecking {
    /// Whether this process is currently trusted for Accessibility.
    func isTrusted() -> Bool

    /// Asks macOS to show its Accessibility prompt and returns the current trust state.
    func promptForTrust() -> Bool
}
