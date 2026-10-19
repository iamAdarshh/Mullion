import AppKit
import MullionCore

/// Reads `NSScreen.screens` and converts them to AX space.
///
/// Screens are read fresh for every action, so a moved or auto-hidden Dock (which changes
/// `visibleFrame`) is respected without observing notifications.
@MainActor
struct SystemScreens: ScreenProviding {
    var screens: [ScreenGeometry] {
        let screens = NSScreen.screens
        // The primary screen (with the menu bar) is always first. It is the flip reference (ARCHITECTURE §4).
        guard let primary = screens.first else { return [] }
        let space = CoordinateSpace(primaryScreenHeight: primary.frame.height)
        return screens.map { screen in
            ScreenGeometry(
                id: Self.identifier(of: screen),
                frame: space.axRect(fromAppKit: screen.frame),
                visibleFrame: space.axRect(fromAppKit: screen.visibleFrame),
                scale: screen.backingScaleFactor
            )
        }
    }

    /// The display's UUID, which survives reboots and reconnection; its name as a fallback.
    private static func identifier(of screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String?
        else {
            return screen.localizedName
        }
        return string
    }
}
