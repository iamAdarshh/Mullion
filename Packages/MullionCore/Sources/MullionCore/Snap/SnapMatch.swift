/// The snap area under the cursor and the screen it belongs to.
public struct SnapMatch: Equatable, Sendable {
    public let area: SnapArea
    public let screen: ScreenGeometry

    public init(area: SnapArea, screen: ScreenGeometry) {
        self.area = area
        self.screen = screen
    }

    /// The action a drop here applies, on `screen`.
    public var action: WindowAction {
        area.action
    }
}
