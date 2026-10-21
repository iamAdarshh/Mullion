import AppKit
import SwiftUI

/// The Settings window (PRD §6.8): one toolbar tab per `SettingsTab`, each a SwiftUI view. The
/// window takes the size of the selected tab and is reused after it's closed.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let tabs = NSTabViewController()

    init(preferences: Preferences) {
        tabs.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let item = NSTabViewItem(viewController: Self.content(for: tab, preferences: preferences))
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            item.identifier = tab.rawValue
            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the window in front of other apps, on `tab` if given. Mullion is a menu bar agent, so
    /// it must activate itself.
    func present(tab: SettingsTab? = nil) {
        if let tab, let index = SettingsTab.allCases.firstIndex(of: tab) {
            tabs.selectedTabViewItemIndex = index
        }
        if window?.isVisible == false {
            window?.center()
        }
        showWindow(nil)
        NSApp.activate()
    }

    private static func content(for tab: SettingsTab, preferences: Preferences) -> NSViewController {
        let view = switch tab {
        case .general: AnyView(GeneralSettingsView(preferences: preferences))
        }
        let hosting = NSHostingController(rootView: view.frame(width: SettingsLayout.width))
        // The tab view controller passes the selected tab's title on to the window.
        hosting.title = tab.title
        // The tab view controller resizes the window to the selected tab's preferred size.
        hosting.sizingOptions = [.preferredContentSize]
        return hosting
    }
}

/// Shared measurements for the Settings tabs.
enum SettingsLayout {
    static let width: CGFloat = 480
}
