import CoreGraphics
import Testing
@testable import Mullion

struct ListedWindowTests {
    private static let ownPID: pid_t = 99

    @Test func parsesAWindowServerEntry() {
        let info: [String: Any] = [
            kCGWindowNumber as String: 42,
            kCGWindowOwnerPID as String: 4242,
            kCGWindowLayer as String: 0,
            kCGWindowAlpha as String: 1.0,
            kCGWindowBounds as String: ["X": 100.0, "Y": -200.0, "Width": 600.0, "Height": 400.0],
        ]
        let window = ListedWindow(info: info)
        #expect(window == ListedWindow(id: 42, pid: 4242, bounds: CGRect(x: 100, y: -200, width: 600, height: 400)))
    }

    @Test func anEntryWithoutBoundsIsSkipped() {
        let info: [String: Any] = [
            kCGWindowNumber as String: 42,
            kCGWindowOwnerPID as String: 4242,
            kCGWindowLayer as String: 0,
        ]
        #expect(ListedWindow(info: info) == nil)
    }

    @Test func picksTheFrontmostWindowUnderThePoint() {
        let front = ListedWindow(id: 1, pid: 10, bounds: CGRect(x: 0, y: 0, width: 300, height: 300))
        let back = ListedWindow(id: 2, pid: 20, bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(ListedWindow.frontmost(in: [front, back], at: CGPoint(x: 100, y: 100), excluding: Self.ownPID) == front)
        #expect(ListedWindow.frontmost(in: [front, back], at: CGPoint(x: 500, y: 100), excluding: Self.ownPID) == back)
    }

    @Test func skipsMenusPanelsAndInvisibleWindows() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let menu = ListedWindow(id: 1, pid: 10, bounds: bounds, layer: 24)
        let invisible = ListedWindow(id: 2, pid: 10, bounds: bounds, alpha: 0)
        let window = ListedWindow(id: 3, pid: 20, bounds: bounds)
        let point = CGPoint(x: 100, y: 100)
        #expect(ListedWindow.frontmost(in: [menu, invisible, window], at: point, excluding: Self.ownPID) == window)
    }

    @Test func mullionsOwnWindowInFrontMeansNoWindow() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let own = ListedWindow(id: 1, pid: Self.ownPID, bounds: bounds)
        let behind = ListedWindow(id: 2, pid: 20, bounds: bounds)
        #expect(ListedWindow.frontmost(in: [own, behind], at: CGPoint(x: 100, y: 100), excluding: Self.ownPID) == nil)
    }
}
