@testable import Mullion

/// Stands in for the welcome window. `close()` calls `onClose` just as `windowWillClose` does.
@MainActor
final class FakeOnboarding: OnboardingPresenting {
    var onClose: (() -> Void)?
    private(set) var presentCount = 0
    private(set) var isOpen = false
    private let onRequestAccess: () -> Void

    init(onRequestAccess: @escaping () -> Void) {
        self.onRequestAccess = onRequestAccess
    }

    func present() {
        presentCount += 1
        isOpen = true
    }

    func close() {
        isOpen = false
        onClose?()
    }

    /// Simulates clicking the window's button.
    func clickButton() {
        onRequestAccess()
    }
}
