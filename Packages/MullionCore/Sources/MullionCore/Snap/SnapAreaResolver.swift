import CoreGraphics

/// Finds the snap area under the cursor during a drag (PRD §6.4). Pure; all points are in AX space.
public enum SnapAreaResolver {
    /// The area under `cursor`, or `nil` when it is in none.
    ///
    /// - Parameter previous: The result for the last cursor position of this drag. Once the cursor is
    ///   in an area it stays there until it is `DragSettings.hysteresis` past the area's edge, so a
    ///   cursor wobbling on a boundary never flickers between areas (AC-5). It also tells a slide along
    ///   the bottom edge from one third into the next, which snaps to two-thirds.
    public static func resolve(
        cursor: CGPoint,
        screens: [ScreenGeometry],
        previous: SnapMatch?,
        settings: DragSettings = .defaults
    ) -> SnapMatch? {
        guard let screen = screens.first(where: { $0.frame.contains(cursor) }) else { return nil }
        let held = previous.flatMap { $0.screen.id == screen.id ? $0.area : nil }
        let found = area(at: cursor, on: screen, settings: settings)

        if let held, held != found {
            let reach = -DragSettings.hysteresis
            if hitRect(of: held, on: screen, settings: settings).insetBy(dx: reach, dy: reach).contains(cursor) {
                return SnapMatch(area: held, screen: screen)
            }
        }
        guard let found else { return nil }
        return SnapMatch(area: slid(into: found, from: held), screen: screen)
    }

    // MARK: Private

    /// The areas a screen has, most specific first: corners win over the edges they sit on.
    private static func areas(on screen: ScreenGeometry) -> [SnapArea] {
        let corners: [SnapArea] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        let top: [SnapArea] = isUltrawide(screen) ? [.topLeftSixth, .top, .topRightSixth] : [.top]
        let bottom: [SnapArea] = screen.isPortrait ? [.bottom] : (0 ..< 3).map { .bottomThird($0) }
        return corners + [.left, .right] + top + bottom
    }

    private static func area(at cursor: CGPoint, on screen: ScreenGeometry, settings: DragSettings) -> SnapArea? {
        areas(on: screen).first { hitRect(of: $0, on: screen, settings: settings).contains(cursor) }
    }

    /// Where the cursor has to be for `area`. Edges stop where the corners start.
    private static func hitRect(of area: SnapArea, on screen: ScreenGeometry, settings: DragSettings) -> CGRect {
        let frame = screen.frame
        let edge = settings.edgeThickness
        let corner = min(settings.cornerSize, frame.width / 2, frame.height / 2)
        let third = frame.width / 3
        // The strip along the top or bottom edge between the corners.
        let between = CGRect(x: frame.minX + corner, y: 0, width: frame.width - 2 * corner, height: edge)
        let topStrip = between.offsetBy(dx: 0, dy: frame.minY)
        let bottomStrip = between.offsetBy(dx: 0, dy: frame.maxY - edge)

        func column(_ index: Int, of strip: CGRect) -> CGRect {
            CGRect(x: frame.minX + CGFloat(index) * third, y: strip.minY, width: third, height: edge)
                .intersection(strip)
        }

        switch area {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            let x = area == .topLeft || area == .bottomLeft ? frame.minX : frame.maxX - corner
            let y = area == .topLeft || area == .topRight ? frame.minY : frame.maxY - corner
            return CGRect(x: x, y: y, width: corner, height: corner)
        case .left: return CGRect(x: frame.minX, y: frame.minY + corner, width: edge, height: frame.height - 2 * corner)
        case .right: return CGRect(
                x: frame.maxX - edge,
                y: frame.minY + corner,
                width: edge,
                height: frame.height - 2 * corner
            )
        case .top: return isUltrawide(screen) ? column(1, of: topStrip) : topStrip
        case .topLeftSixth: return column(0, of: topStrip)
        case .topRightSixth: return column(2, of: topStrip)
        case .bottom: return bottomStrip
        case let .bottomThird(index), let .bottomTwoThirds(_, index): return column(index, of: bottomStrip)
        }
    }

    /// A bottom third reached by sliding from the neighbouring third becomes the two-thirds both cover.
    /// Sliding back into the third the slide started in gives that third alone.
    private static func slid(into found: SnapArea, from held: SnapArea?) -> SnapArea {
        guard case let .bottomThird(now) = found else { return found }
        switch held {
        case let .bottomThird(before) where abs(before - now) == 1:
            return .bottomTwoThirds(start: before, current: now)
        case let .bottomTwoThirds(start, current) where now != start && now != current:
            return .bottomTwoThirds(start: current, current: now)
        default:
            return found
        }
    }

    private static func isUltrawide(_ screen: ScreenGeometry) -> Bool {
        screen.frame.width / screen.frame.height >= DragSettings.ultrawideAspectRatio
    }
}
