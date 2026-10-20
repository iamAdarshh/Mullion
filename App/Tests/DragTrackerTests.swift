import CoreGraphics
import Testing
@testable import Mullion

@MainActor
struct DragTrackerTests {
    private static let pid: pid_t = 4242
    private static let ownPID: pid_t = 99
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
        let windows = FakeWindowController()
        let window: WindowRef
        let tracker: DragTracker
        let recorder = Recorder()

        init(windowPID: pid_t = DragTrackerTests.pid) {
            window = FakeWindowController.makeRef(pid: windowPID)
            tracker = DragTracker(windows: windows, ownPID: DragTrackerTests.ownPID)
            tracker.onMoveStarted = { [recorder] _, point in recorder.started.append(point) }
            tracker.onMoved = { [recorder] _, point in recorder.moved.append(point) }
            tracker.onEnded = { [recorder] _, point in recorder.ended.append(point) }
        }

        func addWindow() async {
            await windows.add(window, frame: DragTrackerTests.frame)
        }

        /// Drags by `offset` from the press point and waits for any AX work it started.
        func drag(by offset: CGFloat) async {
            let point = CGPoint(x: DragTrackerTests.press.x + offset, y: DragTrackerTests.press.y)
            await tracker.mouseDragged(to: point)?.value
        }

        /// The window follows the cursor, as it does when the user drags its title bar.
        func windowFollows(by offset: CGFloat) async {
            await windows.userChange(window, to: DragTrackerTests.frame.offsetBy(dx: offset, dy: 0))
        }
    }

    @Test func aTitleBarDragIsAWindowDrag() async {
        let harness = Harness()
        await harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        await harness.drag(by: 5)
        await harness.windowFollows(by: 8)
        await harness.drag(by: 8)
        #expect(harness.recorder.started.count == 1)

        await harness.drag(by: 50)
        harness.tracker.mouseUp(at: CGPoint(x: 350, y: 110))
        #expect(harness.recorder.moved == [CGPoint(x: 350, y: 110)])
        #expect(harness.recorder.ended == [CGPoint(x: 350, y: 110)])
    }

    @Test func aPressMakesNoAccessibilityCalls() async {
        let harness = Harness()
        await harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        await harness.drag(by: 3)
        #expect(await harness.windows.windowAtCalls == 0)
        #expect(await harness.windows.frameCalls == 0)
    }

    @Test func selectingTextIsNotAWindowDrag() async {
        let harness = Harness()
        await harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        for offset in stride(from: 5, through: 200, by: 5) {
            await harness.drag(by: CGFloat(offset))
        }
        harness.tracker.mouseUp(at: Self.press)
        #expect(harness.recorder.started.isEmpty)
        #expect(harness.recorder.ended.isEmpty)
        // One read when identified, then one per sample until the cursor is 30 pt further: no more.
        #expect(await harness.windows.frameCalls <= 1 + Int(DragTracker.giveUpDistance / 5) + 1)
    }

    @Test func resizingFromTheLeftEdgeIsNotAWindowDrag() async {
        let harness = Harness()
        await harness.addWindow()
        harness.tracker.mouseDown(at: CGPoint(x: 101, y: 300))
        await harness.tracker.mouseDragged(to: CGPoint(x: 95, y: 300))?.value
        await harness.windows.userChange(harness.window, to: CGRect(x: 90, y: 100, width: 610, height: 400))
        await harness.tracker.mouseDragged(to: CGPoint(x: 90, y: 300))?.value
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func draggingOnTheDesktopIsNotAWindowDrag() async {
        let harness = Harness()
        harness.tracker.mouseDown(at: Self.press)
        await harness.drag(by: 5)
        await harness.drag(by: 10)
        #expect(await harness.windows.windowAtCalls == 1)
        #expect(await harness.windows.frameCalls == 0)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func mullionsOwnWindowsAreNeverDragged() async {
        let harness = Harness(windowPID: Self.ownPID)
        await harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        await harness.drag(by: 5)
        await harness.windowFollows(by: 8)
        await harness.drag(by: 8)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func anAnswerForAFinishedDragIsDropped() async {
        let harness = Harness()
        await harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        let lookUp = harness.tracker.mouseDragged(to: CGPoint(x: 310, y: 110))
        harness.tracker.mouseUp(at: CGPoint(x: 310, y: 110))
        await lookUp?.value
        await harness.windowFollows(by: 20)
        // No press since the release: this drag event belongs to nothing.
        #expect(harness.tracker.mouseDragged(to: CGPoint(x: 330, y: 110)) == nil)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func aWindowThatClosesMidDragIsIgnored() async {
        let harness = Harness()
        await harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        await harness.drag(by: 5)
        await harness.windows.close(harness.window)
        await harness.drag(by: 8)
        #expect(harness.tracker.mouseDragged(to: CGPoint(x: 400, y: 110)) == nil)
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func aDragWithoutAPressIsIgnored() {
        let harness = Harness()
        #expect(harness.tracker.mouseDragged(to: Self.press) == nil)
    }
}
