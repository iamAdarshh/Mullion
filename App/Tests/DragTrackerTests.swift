import CoreGraphics
import Testing
@testable import Mullion

@MainActor
struct DragTrackerTests {
    private static let pid: pid_t = 4242
    private static let ownPID: pid_t = 99
    private static let windowID: CGWindowID = 7
    private static let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
    /// On the window's title bar.
    private static let press = CGPoint(x: 300, y: 110)

    @MainActor
    private final class Recorder {
        var started: [CGPoint] = []
        var moved: [CGPoint] = []
        var ended: [CGPoint] = []
    }

    @MainActor
    private struct Harness {
        let windows = FakeWindowList()
        let tracker: DragTracker
        let recorder = Recorder()

        init() {
            tracker = DragTracker(windowList: windows, ownPID: DragTrackerTests.ownPID)
            tracker.onMoveStarted = { [recorder] _, point in recorder.started.append(point) }
            tracker.onMoved = { [recorder] _, point in recorder.moved.append(point) }
            tracker.onEnded = { [recorder] _, point in recorder.ended.append(point) }
        }

        func addWindow(pid: pid_t = DragTrackerTests.pid) {
            windows.add(ListedWindow(id: DragTrackerTests.windowID, pid: pid, bounds: DragTrackerTests.frame))
        }

        /// Drags to `offset` points right of the press point.
        func drag(by offset: CGFloat) {
            tracker.mouseDragged(to: CGPoint(x: DragTrackerTests.press.x + offset, y: DragTrackerTests.press.y))
        }

        /// The window follows the cursor, as it does when the user drags its title bar.
        func windowFollows(by offset: CGFloat) {
            windows.userChange(DragTrackerTests.windowID, to: DragTrackerTests.frame.offsetBy(dx: offset, dy: 0))
        }
    }

    @Test func aTitleBarDragIsAWindowDrag() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 5)
        harness.windowFollows(by: 8)
        harness.drag(by: 8)
        #expect(harness.recorder.started == [CGPoint(x: 308, y: 110)])

        harness.drag(by: 50)
        harness.tracker.mouseUp(at: CGPoint(x: 350, y: 110))
        #expect(harness.recorder.moved == [CGPoint(x: 350, y: 110)])
        #expect(harness.recorder.ended == [CGPoint(x: 350, y: 110)])
    }

    @Test func aPressAndASmallWobbleReadNothing() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 3)
        #expect(harness.windows.reads == 0)
    }

    @Test func selectingTextIsNotAWindowDrag() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        for offset in stride(from: 5, through: 200, by: 5) {
            harness.drag(by: CGFloat(offset))
        }
        harness.tracker.mouseUp(at: Self.press)
        #expect(harness.recorder.started.isEmpty)
        #expect(harness.recorder.ended.isEmpty)
        // One lookup, then one read per sample until the cursor is 30 pt further: no more after that.
        #expect(harness.windows.reads == 1 + Int(DragTracker.giveUpDistance / 5))
    }

    @Test func resizingFromTheLeftEdgeIsNotAWindowDrag() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: CGPoint(x: 101, y: 300))
        harness.tracker.mouseDragged(to: CGPoint(x: 105, y: 300))
        harness.windows.userChange(Self.windowID, to: CGRect(x: 90, y: 100, width: 610, height: 400))
        harness.tracker.mouseDragged(to: CGPoint(x: 90, y: 300))
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func draggingOnTheDesktopIsNotAWindowDrag() {
        let harness = Harness()
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 5)
        harness.drag(by: 10)
        #expect(harness.windows.reads == 1)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func mullionsOwnWindowsAreNeverDragged() {
        let harness = Harness()
        harness.addWindow(pid: Self.ownPID)
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 5)
        harness.windowFollows(by: 8)
        harness.drag(by: 8)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func aWindowThatClosesMidDragIsIgnored() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 5)
        harness.windows.close(Self.windowID)
        harness.drag(by: 8)
        harness.drag(by: 20)
        #expect(harness.windows.reads == 2)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func aReleaseEndsTheDrag() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 5)
        harness.tracker.mouseUp(at: Self.press)
        harness.windowFollows(by: 20)
        // No press since the release: this drag event belongs to nothing.
        harness.drag(by: 20)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func aDragWithoutAPressIsIgnored() {
        let harness = Harness()
        harness.addWindow()
        harness.drag(by: 20)
        #expect(harness.windows.reads == 0)
    }
}
