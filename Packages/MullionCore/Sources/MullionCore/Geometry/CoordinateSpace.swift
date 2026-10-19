import CoreGraphics

/// Converts between the two global coordinate spaces of macOS (ARCHITECTURE §4).
///
/// - AppKit: origin at the bottom-left of the primary screen, y grows upwards
///   (`NSScreen.frame`, `NSEvent.mouseLocation`).
/// - AX / Quartz: origin at the top-left of the primary screen, y grows downwards
///   (`AXUIElement` position, `CGEvent.location`).
///
/// This is the only place in Mullion that flips y. All other Core APIs take and return AX space.
public struct CoordinateSpace: Equatable, Sendable {
    /// Height of the primary screen: the one with the menu bar, `NSScreen.screens.first`.
    /// Not the screen of the key window, which can be any display.
    public let primaryScreenHeight: CGFloat

    public init(primaryScreenHeight: CGFloat) {
        self.primaryScreenHeight = primaryScreenHeight
    }

    /// Converts an AppKit rect to AX space.
    public func axRect(fromAppKit rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Converts an AX rect to AppKit space. The flip is its own inverse.
    public func appKitRect(fromAX rect: CGRect) -> CGRect {
        axRect(fromAppKit: rect)
    }

    /// Converts an AppKit point to AX space.
    public func axPoint(fromAppKit point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// Converts an AX point to AppKit space.
    public func appKitPoint(fromAX point: CGPoint) -> CGPoint {
        axPoint(fromAppKit: point)
    }
}
