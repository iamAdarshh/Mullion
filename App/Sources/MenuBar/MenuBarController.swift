import AppKit
import KeyboardShortcuts
import MullionCore

/// Owns the status bar item and its menu (PRD §6.7).
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, NSMenuItemValidation {
    /// Called when the user chooses *Grant Accessibility access…*.
    var onGrantAccess: (() -> Void)?
    /// Called just before the menu opens, so callers can refresh state.
    var onMenuWillOpen: (() -> Void)?
    /// Called when the user chooses an action from the menu.
    var onAction: ((WindowAction) -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let grantItem = NSMenuItem()
    private let grantSeparator = NSMenuItem.separator()
    private var isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
        super.init()
        buildMenu()
        statusItem.menu = menu
        setAccessibilityTrusted(isTrusted)
    }

    /// Updates the icon and menu for the current Accessibility state (PRD §6.9.3).
    /// While untrusted, every action item is disabled.
    func setAccessibilityTrusted(_ trusted: Bool) {
        isTrusted = trusted
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

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        item.action == #selector(performAction(_:)) ? isTrusted : true
    }

    // MARK: Private

    private func buildMenu() {
        menu.delegate = self

        grantItem.title = String(localized: "Grant Accessibility access…")
        grantItem.action = #selector(grantAccess)
        grantItem.target = self
        menu.addItem(grantItem)
        menu.addItem(grantSeparator)

        for group in WindowAction.Group.allCases {
            menu.addItem(.sectionHeader(title: group.title))
            for action in WindowAction.allCases where action.group == group {
                menu.addItem(item(for: action))
            }
            menu.addItem(.separator())
        }

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

    private func item(for action: WindowAction) -> NSMenuItem {
        let item = NSMenuItem(title: action.title, action: #selector(performAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = action.rawValue
        // Shows the action's global shortcut and follows it when the user changes it.
        item.setShortcut(for: DefaultShortcuts.name(for: action))
        return item
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let action = WindowAction(rawValue: rawValue)
        else { return }
        onAction?(action)
    }

    @objc private func grantAccess() {
        onGrantAccess?()
    }
}
