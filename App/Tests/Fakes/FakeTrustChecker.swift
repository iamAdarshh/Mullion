@testable import Mullion

@MainActor
final class FakeTrustChecker: AccessibilityTrustChecking {
    var trusted: Bool
    private(set) var promptCount = 0

    init(trusted: Bool) {
        self.trusted = trusted
    }

    func isTrusted() -> Bool {
        trusted
    }

    func promptForTrust() -> Bool {
        promptCount += 1
        return trusted
    }
}
