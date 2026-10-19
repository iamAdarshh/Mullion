import AppKit

/// Owns the status bar item and its menu.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// Called when the user chooses *Grant Accessibility access…*.
    var onGrantAccess: (() -> Void)?
    /// Called just before the menu opens, so callers can refresh state.
    var onMenuWillOpen: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let grantItem = NSMenuItem()
    private let grantSeparator = NSMenuItem.separator()

    init(isTrusted: Bool) {
        super.init()
        buildMenu()
        statusItem.menu = menu
        setAccessibilityTrusted(isTrusted)
    }

    /// Updates the icon and menu for the current Accessibility state (PRD §6.9.3).
    func setAccessibilityTrusted(_ trusted: Bool) {
        grantItem.isHidden = trusted
        grantSeparator.isHidden = trusted

        // Placeholder symbols until the original artwork lands in M3.
        let symbol = trusted ? "rectangle.split.2x1" : "exclamationmark.triangle"
        let description = trusted
            ? String(localized: "Mullion")
            : String(localized: "Mullion: Accessibility access needed")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = description
    }

    func menuWillOpen(_: NSMenu) {
        onMenuWillOpen?()
    }

    private func buildMenu() {
        menu.delegate = self

        grantItem.title = String(localized: "Grant Accessibility access…")
        grantItem.action = #selector(grantAccess)
        grantItem.target = self
        menu.addItem(grantItem)
        menu.addItem(grantSeparator)

        // No action until the Settings window exists (M3), so AppKit shows it disabled.
        menu.addItem(withTitle: String(localized: "Settings…"), action: nil, keyEquivalent: ",")
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: String(localized: "Quit Mullion"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
    }

    @objc private func grantAccess() {
        onGrantAccess?()
    }
}
