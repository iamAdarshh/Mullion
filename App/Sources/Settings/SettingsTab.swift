import Foundation

/// A tab of the Settings window (PRD §6.8), in toolbar order.
enum SettingsTab: String, CaseIterable {
    case general
    case shortcuts
    case drag
    case ignoredApps
    case about

    var title: String {
        switch self {
        case .general: String(localized: "General", comment: "Settings tab")
        case .shortcuts: String(localized: "Shortcuts", comment: "Settings tab")
        case .drag: String(localized: "Drag", comment: "Settings tab")
        case .ignoredApps: String(localized: "Ignored Apps", comment: "Settings tab")
        case .about: String(localized: "About", comment: "Settings tab")
        }
    }

    /// The SF Symbol shown in the toolbar.
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "keyboard"
        case .drag: "hand.draw"
        case .ignoredApps: "nosign"
        case .about: "info.circle"
        }
    }
}
