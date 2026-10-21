import AppKit

/// How the drag-to-snap preview looks (PRD §6.8 Drag).
struct PreviewStyle: Equatable {
    static let defaultOpacity = 0.2
    static let opacityRange = 0.1 ... 0.6

    /// The fill and border colour; `nil` follows the system accent colour.
    var color: NSColor?
    /// The fill's opacity, within `opacityRange`. The border is three times as opaque.
    var opacity = defaultOpacity

    /// Read each time a preview is shown: the user can change the accent colour while Mullion runs.
    var resolvedColor: NSColor {
        color ?? .controlAccentColor
    }

    var borderOpacity: Double {
        min(opacity * 3, 1)
    }
}
