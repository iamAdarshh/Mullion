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
    /// The app the *Ignore* item is about, asked each time the menu opens. `nil` hides the item.
    var ignorableApp: (() -> IgnorableApp?)?
    /// Called when the user chooses *Settings…*.
    var onOpenSettings: (() -> Void)?
    /// Called when the user puts an app on the ignore list (`true`) or takes it off, with its bundle ID.
    var onSetIgnored: ((Bool, String) -> Void)?

    /// An app that can go on the drag-to-snap ignore list (PRD §6.4, §6.7).
    struct IgnorableApp {
        let bundleID: String
        let name: String
        let isIgnored: Bool
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let grantItem = NSMenuItem()
    private let grantSeparator = NSMenuItem.separator()
    private let ignoreItem = NSMenuItem()
    private let ignoreSeparator = NSMenuItem.separator()
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
        updateIgnoreItem()
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

        ignoreItem.action = #selector(toggleIgnored(_:))
        ignoreItem.target = self
        menu.addItem(ignoreItem)
        menu.addItem(ignoreSeparator)

        let settings = NSMenuItem(
            title: String(localized: "Settings…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)
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

    /// Names the frontmost app, ticked when it's ignored. Hidden when there is none, or it's Mullion.
    private func updateIgnoreItem() {
        let app = ignorableApp?()
        ignoreItem.isHidden = app == nil
        ignoreSeparator.isHidden = app == nil
        guard let app else { return }
        ignoreItem.title = String(
            localized: "Ignore “\(app.name)”",
            comment: "Menu item. Windows of the named app never snap when dragged."
        )
        ignoreItem.state = app.isIgnored ? .on : .off
        ignoreItem.representedObject = app.bundleID
    }

    @objc private func toggleIgnored(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        onSetIgnored?(sender.state != .on, bundleID)
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func grantAccess() {
        onGrantAccess?()
    }
}
