import Foundation

/// A tab of the Settings window (PRD §6.8), in toolbar order.
enum SettingsTab: String, CaseIterable {
    case general
    case drag

    var title: String {
        switch self {
        case .general: String(localized: "General", comment: "Settings tab")
        case .drag: String(localized: "Drag", comment: "Settings tab")
        }
    }

    /// The SF Symbol shown in the toolbar.
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .drag: "hand.draw"
        }
    }
}
