import CoreGraphics
import MullionCore
@testable import Mullion

/// Fixed screens in AX space. Mirrors the MullionCore fixtures that the dispatcher tests need.
@MainActor
struct FakeScreens: ScreenProviding {
    /// 13" MacBook Air: visible frame (0, 37, 1470, 919) below a 37 pt notched menu bar.
    static let laptop = ScreenGeometry(
        id: "laptop",
        frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        visibleFrame: CGRect(x: 0, y: 37, width: 1470, height: 919),
        scale: 2
    )

    /// Studio Display to the right of the laptop: visible frame (1470, -217, 2560, 1415).
    static let externalRight = ScreenGeometry(
        id: "externalRight",
        frame: CGRect(x: 1470, y: -242, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1470, y: -217, width: 2560, height: 1415),
        scale: 2
    )

    var screens: [ScreenGeometry]
}
