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
        var startedWindows: [DraggedWindow] = []
        var moved: [CGPoint] = []
        var ended: [CGPoint] = []
        var droppedWindows: [DroppedWindow] = []
        var cancelled = 0
        var isButtonDown = true
    }

    @MainActor
    private struct Harness {
        let windows = FakeWindowList()
        let scheduler = FakeScheduler()
        let tracker: DragTracker
        let recorder = Recorder()

        init() {
            tracker = DragTracker(
                windowList: windows,
                ownPID: DragTrackerTests.ownPID,
                scheduler: scheduler,
                isLeftButtonDown: { [recorder] in recorder.isButtonDown }
            )
            tracker.onMoveStarted = { [recorder] window, point in
                recorder.started.append(point)
                recorder.startedWindows.append(window)
            }
            tracker.onMoved = { [recorder] _, point in recorder.moved.append(point) }
            tracker.onEnded = { [recorder] window, point in
                recorder.ended.append(point)
                recorder.droppedWindows.append(window)
            }
            tracker.onCancelled = { [recorder] _ in recorder.cancelled += 1 }
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

        /// A title-bar drag: the window server moves the window before Mullion sees each event.
        func dragWindow(by offset: CGFloat) {
            windowFollows(by: offset)
            drag(by: offset)
        }

        /// Starts a title-bar drag and lets it be recognised.
        func startWindowDrag() {
            tracker.mouseDown(at: DragTrackerTests.press)
            dragWindow(by: 5)
            dragWindow(by: 8)
        }
    }

    @Test func aTitleBarDragIsAWindowDrag() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        #expect(harness.recorder.started == [CGPoint(x: 308, y: 110)])
        #expect(harness.recorder.startedWindows.first?.frameBeforeDrag == Self.frame)

        harness.dragWindow(by: 50)
        harness.tracker.mouseUp(at: CGPoint(x: 350, y: 110))
        #expect(harness.recorder.moved == [CGPoint(x: 350, y: 110)])
        #expect(harness.recorder.ended == [CGPoint(x: 350, y: 110)])
    }

    @Test func theDropPassesWhereTheWindowIsNowAndWhereItStarted() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.dragWindow(by: 50)
        harness.tracker.mouseUp(at: CGPoint(x: 350, y: 110))
        #expect(harness.recorder.droppedWindows == [
            DroppedWindow(pid: Self.pid, frameBeforeDrag: Self.frame, frame: Self.frame.offsetBy(dx: 50, dy: 0)),
        ])
    }

    @Test func aWindowThatClosesBeforeTheDropIsCancelled() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.windows.close(Self.windowID)
        harness.tracker.mouseUp(at: Self.press)
        #expect(harness.recorder.ended.isEmpty)
        #expect(harness.recorder.cancelled == 1)
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
        // One lookup under the cursor and the press point together; nothing after that.
        #expect(harness.windows.reads == 1)
        #expect(harness.recorder.started.isEmpty)
    }

    // Regression: the window was looked up under the press point, which a fast drag that started near
    // the window's edge had already left, so the drag was never recognised.
    @Test func aFastDragFromNearTheEdgeIsAWindowDrag() {
        let harness = Harness()
        harness.addWindow()
        let press = CGPoint(x: 300, y: Self.frame.minY + 3)
        harness.tracker.mouseDown(at: press)
        // By the first event the window has moved 12 pt down: the press point is above it now.
        harness.windows.userChange(Self.windowID, to: Self.frame.offsetBy(dx: 0, dy: 12))
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 12))
        harness.windows.userChange(Self.windowID, to: Self.frame.offsetBy(dx: 0, dy: 20))
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 20))
        #expect(harness.recorder.startedWindows.first?.frameBeforeDrag == Self.frame)
    }

    @Test func mullionsOwnWindowsAreNeverDragged() {
        let harness = Harness()
        harness.addWindow(pid: Self.ownPID)
        harness.startWindowDrag()
        #expect(harness.recorder.started.isEmpty)
    }

    @Test func cancellingAWindowDragTellsTheListener() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.tracker.cancel()
        #expect(harness.recorder.cancelled == 1)
        #expect(!harness.tracker.isDraggingWindow)
        // The release that follows belongs to nothing.
        harness.tracker.mouseUp(at: Self.press)
        #expect(harness.recorder.ended.isEmpty)
    }

    @Test func cancellingBeforeAWindowDragIsSilent() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 5)
        harness.tracker.cancel()
        #expect(harness.recorder.cancelled == 0)
    }

    @Test func aPressDuringAWindowDragCancelsItAndStartsAfresh() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        #expect(harness.tracker.isDraggingWindow)
        // The release was missed: the next press must not leave the old drag running.
        harness.windows.userChange(Self.windowID, to: Self.frame)
        harness.startWindowDrag()
        #expect(harness.recorder.cancelled == 1)
        #expect(harness.recorder.started.count == 2)
    }

    // Regression: the window server moves the window before Mullion handles the event, so the event's
    // position lags. Looking the window up there missed a window dragged fast from near its edge.
    @Test func aWindowAheadOfTheEventIsStillFound() {
        let harness = Harness()
        harness.addWindow()
        let press = CGPoint(x: 300, y: Self.frame.minY + 3)
        harness.tracker.mouseDown(at: press)
        // The event says 12 pt, but the window and the cursor are already 40 pt down.
        harness.windows.userChange(Self.windowID, to: Self.frame.offsetBy(dx: 0, dy: 40))
        harness.windows.cursorPosition = CGPoint(x: 300, y: press.y + 40)
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 12))
        harness.windows.userChange(Self.windowID, to: Self.frame.offsetBy(dx: 0, dy: 48))
        harness.windows.cursorPosition = CGPoint(x: 300, y: press.y + 48)
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 20))
        #expect(harness.recorder.startedWindows.first?.frameBeforeDrag == Self.frame)
        // Snap areas still follow the event.
        #expect(harness.recorder.started == [CGPoint(x: 300, y: press.y + 20)])
    }

    @Test func aWindowBehindTheCursorIsFoundAtThePress() {
        let harness = Harness()
        harness.addWindow()
        // Pressed near the bottom edge; the cursor has left the window before the window starts to move.
        let press = CGPoint(x: 300, y: Self.frame.maxY - 3)
        harness.tracker.mouseDown(at: press)
        harness.windows.cursorPosition = CGPoint(x: 300, y: press.y + 12)
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 12))
        harness.windows.userChange(Self.windowID, to: Self.frame.offsetBy(dx: 0, dy: 20))
        harness.windows.cursorPosition = CGPoint(x: 300, y: press.y + 20)
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 20))
        #expect(harness.recorder.started.count == 1)
    }

    // Regression: the cursor was looked up first and the press point only over an empty background,
    // so a window lagging the cursor in front of another window was never found.
    @Test func aLaggingWindowInFrontOfAnotherIsFoundAtThePress() {
        let harness = Harness()
        harness.addWindow()
        // Behind the dragged window and reaching further down, so the cursor is over it once it leaves.
        harness.windows.add(ListedWindow(id: 8, pid: 5151, bounds: CGRect(x: 0, y: 0, width: 1000, height: 900)))
        let press = CGPoint(x: 300, y: Self.frame.maxY - 3)
        harness.tracker.mouseDown(at: press)
        harness.windows.cursorPosition = CGPoint(x: 300, y: press.y + 12)
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 12))
        harness.windows.userChange(Self.windowID, to: Self.frame.offsetBy(dx: 0, dy: 20))
        harness.windows.cursorPosition = CGPoint(x: 300, y: press.y + 20)
        harness.tracker.mouseDragged(to: CGPoint(x: 300, y: press.y + 20))
        #expect(harness.recorder.startedWindows.map(\.id) == [Self.windowID])
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

// MARK: Missed releases

extension DragTrackerTests {
    @Test func aWindowDragWithTheButtonUpOnTwoChecksIsCancelled() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.recorder.isButtonDown = false
        harness.scheduler.fire()
        #expect(harness.recorder.cancelled == 0)
        harness.scheduler.fire()
        #expect(harness.recorder.cancelled == 1)
        #expect(harness.scheduler.activeTasks.isEmpty)
    }

    // Regression: the button state changes the moment the button is released, but the release event
    // reaches Mullion later. A check in between cancelled the drag, and the drop that followed was lost.
    @Test func aReleaseQueuedBehindAButtonCheckStillDrops() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.recorder.isButtonDown = false
        harness.scheduler.fire()
        harness.tracker.mouseUp(at: CGPoint(x: 308, y: 110))
        #expect(harness.recorder.ended.count == 1)
        #expect(harness.recorder.cancelled == 0)
    }

    @Test func theButtonHeldAgainResetsTheCheck() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.recorder.isButtonDown = false
        harness.scheduler.fire()
        harness.recorder.isButtonDown = true
        harness.scheduler.fire()
        harness.recorder.isButtonDown = false
        harness.scheduler.fire()
        #expect(harness.recorder.cancelled == 0)
    }

    @Test func aDragEventResetsTheCheck() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.recorder.isButtonDown = false
        harness.scheduler.fire()
        harness.dragWindow(by: 20)
        harness.scheduler.fire()
        #expect(harness.recorder.cancelled == 0)
    }

    @Test func holdingTheWindowStillKeepsTheDrag() {
        let harness = Harness()
        harness.addWindow()
        harness.startWindowDrag()
        harness.scheduler.fire()
        harness.scheduler.fire()
        #expect(harness.recorder.cancelled == 0)
        #expect(harness.tracker.isDraggingWindow)
    }

    @Test func theButtonIsOnlyCheckedDuringAWindowDrag() {
        let harness = Harness()
        harness.addWindow()
        harness.tracker.mouseDown(at: Self.press)
        harness.drag(by: 5)
        #expect(harness.scheduler.tasks.isEmpty)
        harness.dragWindow(by: 8)
        #expect(harness.scheduler.activeTasks.count == 1)
        harness.tracker.mouseUp(at: Self.press)
        #expect(harness.scheduler.activeTasks.isEmpty)
    }
}
