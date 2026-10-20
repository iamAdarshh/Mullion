import CoreGraphics
import MullionCore
@testable import Mullion

/// Records what the preview overlay was asked to show.
@MainActor
final class FakePreview: SnapPreviewing {
    private(set) var shown: [(rect: CGRect, screenID: String)] = []
    private(set) var hides = 0

    /// What is on screen now: the last rect shown, unless it was hidden since.
    private(set) var visible: CGRect?

    /// The screens of each `prepare(for:)`, by id.
    private(set) var prepared: [[String]] = []

    func prepare(for screens: [ScreenGeometry]) {
        prepared.append(screens.map(\.id))
    }

    func show(_ rect: CGRect, on screen: ScreenGeometry) {
        shown.append((rect, screen.id))
        visible = rect
    }

    func hide() {
        hides += 1
        visible = nil
    }
}
