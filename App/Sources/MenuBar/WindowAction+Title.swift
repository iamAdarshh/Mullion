import Foundation
import MullionCore

extension WindowAction {
    /// The localised menu title (PRD §6.1 names).
    var title: String {
        Self.titles[self].map { String(localized: $0) } ?? rawValue
    }

    private static let titles: [WindowAction: LocalizedStringResource] = [
        .leftHalf: LocalizedStringResource("Left Half"),
        .rightHalf: LocalizedStringResource("Right Half"),
        .topHalf: LocalizedStringResource("Top Half"),
        .bottomHalf: LocalizedStringResource("Bottom Half"),
        .topLeft: LocalizedStringResource("Top Left"),
        .topRight: LocalizedStringResource("Top Right"),
        .bottomLeft: LocalizedStringResource("Bottom Left"),
        .bottomRight: LocalizedStringResource("Bottom Right"),
        .firstThird: LocalizedStringResource("First Third"),
        .centerThird: LocalizedStringResource("Center Third"),
        .lastThird: LocalizedStringResource("Last Third"),
        .firstTwoThirds: LocalizedStringResource("First Two-Thirds"),
        .lastTwoThirds: LocalizedStringResource("Last Two-Thirds"),
        .topLeftSixth: LocalizedStringResource("Top Left Sixth"),
        .topCenterSixth: LocalizedStringResource("Top Center Sixth"),
        .topRightSixth: LocalizedStringResource("Top Right Sixth"),
        .bottomLeftSixth: LocalizedStringResource("Bottom Left Sixth"),
        .bottomCenterSixth: LocalizedStringResource("Bottom Center Sixth"),
        .bottomRightSixth: LocalizedStringResource("Bottom Right Sixth"),
        .maximize: LocalizedStringResource("Maximize"),
        .almostMaximize: LocalizedStringResource("Almost Maximize"),
        .maximizeHeight: LocalizedStringResource("Maximize Height"),
        .center: LocalizedStringResource("Center"),
        .larger: LocalizedStringResource("Grow"),
        .smaller: LocalizedStringResource("Shrink"),
        .restore: LocalizedStringResource("Restore"),
        .nextDisplay: LocalizedStringResource("Move to Next Display"),
        .previousDisplay: LocalizedStringResource("Move to Previous Display"),
    ]
}

extension WindowAction.Group {
    /// The localised menu section title (PRD §6.7).
    var title: String {
        switch self {
        case .halves: String(localized: "Halves")
        case .quarters: String(localized: "Quarters")
        case .thirds: String(localized: "Thirds")
        case .sixths: String(localized: "Sixths")
        case .other: String(localized: "Other")
        case .displays: String(localized: "Displays")
        }
    }
}
