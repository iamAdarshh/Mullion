import AppKit
import SwiftUI

/// Hosts `OnboardingView` in a standard window.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    /// Called when the window closes, whether the user closed it or access was granted.
    var onClose: (() -> Void)?

    init(onRequestAccess: @escaping () -> Void) {
        let hosting = NSHostingController(rootView: OnboardingView(onRequestAccess: onRequestAccess))
        hosting.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = String(localized: "Welcome to Mullion")
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the window in front of other apps. Mullion is a menu bar agent, so it must activate itself.
    func present() {
        window?.center()
        showWindow(nil)
        NSApp.activate()
    }

    func windowWillClose(_: Notification) {
        onClose?()
    }
}
