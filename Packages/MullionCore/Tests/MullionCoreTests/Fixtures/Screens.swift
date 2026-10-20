import CoreGraphics
import MullionCore

/// Screen fixtures in AX space: origin at the top-left of the primary screen, y grows downwards.
///
/// The first screen of every arrangement is the primary screen (the one with the menu bar),
/// so it always starts at (0, 0). Visible frames exclude the menu bar (37 pt on the notched
/// MacBook Air, 25 pt elsewhere) and, where noted, the Dock.
enum Screens {
    // MARK: Single screens, each as the primary display

    static let macBookAir13 = screen(
        "macBookAir13",
        CGRect(x: 0, y: 0, width: 1470, height: 956),
        menuBar: 37,
        scale: 2
    )
    static let macBookAir13DockLeft = screen(
        "macBookAir13DockLeft",
        CGRect(x: 0, y: 0, width: 1470, height: 956),
        menuBar: 37,
        dockLeft: 64,
        scale: 2
    )
    static let studioDisplay = screen("studioDisplay", CGRect(x: 0, y: 0, width: 2560, height: 1440), scale: 2)
    static let ultrawide = screen("ultrawide", CGRect(x: 0, y: 0, width: 3440, height: 1440), scale: 1)
    static let portrait1080 = screen("portrait1080", CGRect(x: 0, y: 0, width: 1080, height: 1920), scale: 1)

    // MARK: Arrangements (primary first)

    /// External display to the right of the laptop, vertically centred on it.
    static let laptopLeftOfExternal = [
        macBookAir13,
        screen("studioRight", CGRect(x: 1470, y: -242, width: 2560, height: 1440), scale: 2),
    ]

    /// External display placed above the laptop (negative AX y).
    static let externalAbovePrimary = [
        macBookAir13,
        screen("studioAbove", CGRect(x: -545, y: -1440, width: 2560, height: 1440), scale: 2),
    ]

    /// Portrait 1× display to the right of a 2× laptop (mixed scale).
    static let portraitRightOfPrimary = [
        macBookAir13,
        screen("portraitRight", CGRect(x: 1470, y: -482, width: 1080, height: 1920), scale: 1),
    ]

    /// Portrait 1× display to the left of the laptop (negative AX x and y).
    static let portraitLeftOfPrimary = [
        macBookAir13,
        screen("portraitLeft", CGRect(x: -1080, y: -482, width: 1080, height: 1920), scale: 1),
    ]

    /// Ultrawide 1× display to the left of the laptop (negative AX x and y).
    static let ultrawideLeftOfPrimary = [
        macBookAir13,
        screen("ultrawideLeft", CGRect(x: -3440, y: -242, width: 3440, height: 1440), scale: 1),
    ]

    /// Studio Display left of the laptop (negative AX x), portrait display on the right.
    static let threeDisplays = [
        macBookAir13,
        screen("studioLeft", CGRect(x: -2560, y: -242, width: 2560, height: 1440), scale: 2),
        screen("portraitRight", CGRect(x: 1470, y: -482, width: 1080, height: 1920), scale: 1),
    ]

    static let arrangements: [[ScreenGeometry]] = [
        [macBookAir13], [macBookAir13DockLeft], [studioDisplay], [ultrawide], [portrait1080],
        laptopLeftOfExternal, externalAbovePrimary, portraitRightOfPrimary, portraitLeftOfPrimary,
        ultrawideLeftOfPrimary,
        threeDisplays,
    ]

    /// Every screen of every arrangement, including non-primary screens left of and above the primary.
    static let all: [ScreenGeometry] = arrangements.flatMap(\.self)

    /// Every landscape screen: these split the bottom edge into thirds for drag-to-snap.
    static let landscape = all.filter { !$0.isPortrait }

    /// Every ultrawide screen (21:9 or wider): these split the top edge into sixths for drag-to-snap.
    static let ultrawideScreens = all.filter { $0.frame.width / $0.frame.height >= 21 / 9 }

    // MARK: Helpers

    private static func screen(
        _ id: String,
        _ frame: CGRect,
        menuBar: CGFloat = 25,
        dockLeft: CGFloat = 0,
        scale: CGFloat
    ) -> ScreenGeometry {
        let visible = CGRect(
            x: frame.minX + dockLeft,
            y: frame.minY + menuBar,
            width: frame.width - dockLeft,
            height: frame.height - menuBar
        )
        return ScreenGeometry(id: id, frame: frame, visibleFrame: visible, scale: scale)
    }
}
