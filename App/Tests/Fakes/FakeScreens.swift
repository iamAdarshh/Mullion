import CoreGraphics
import MullionCore
@testable import Mullion

/// Fixed screens in AX space. Mirrors the MullionCore fixtures that the dispatcher tests need.
@MainActor
struct FakeScreens: ScreenProviding {
    /// 13" MacBook Air: visible frame (0, 37, 1470, 919) below a 37 pt notched menu bar.
    nonisolated static let laptop = ScreenGeometry(
        id: "laptop",
        frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        visibleFrame: CGRect(x: 0, y: 37, width: 1470, height: 919),
        scale: 2
    )

    /// Studio Display to the right of the laptop: visible frame (1470, -217, 2560, 1415).
    nonisolated static let externalRight = ScreenGeometry(
        id: "externalRight",
        frame: CGRect(x: 1470, y: -242, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1470, y: -217, width: 2560, height: 1415),
        scale: 2
    )

    /// Studio Display above the laptop (negative AX y), with a 25 pt menu bar.
    nonisolated static let externalAbove = ScreenGeometry(
        id: "externalAbove",
        frame: CGRect(x: -545, y: -1440, width: 2560, height: 1440),
        visibleFrame: CGRect(x: -545, y: -1415, width: 2560, height: 1415),
        scale: 2
    )

    /// Portrait 1× display left of the laptop (negative AX x and y), with a 25 pt menu bar.
    nonisolated static let portraitLeft = ScreenGeometry(
        id: "portraitLeft",
        frame: CGRect(x: -1080, y: -482, width: 1080, height: 1920),
        visibleFrame: CGRect(x: -1080, y: -457, width: 1080, height: 1895),
        scale: 1
    )

    var screens: [ScreenGeometry]
}
