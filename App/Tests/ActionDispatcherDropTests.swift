import ApplicationServices
import CoreGraphics
import MullionCore
import Testing
@testable import Mullion

/// Drag to snap: the dispatcher acts on the window that was dropped, not the focused one (PRD §6.4).
@MainActor
struct ActionDispatcherDropTests {
    private static let pid: pid_t = 4242
    /// Where the window was before the drag.
    private static let beforeDrag = CGRect(x: 300, y: 300, width: 600, height: 400)
    /// Where the window server says it is at the drop.
    private static let atDrop = CGRect(x: 5, y: 200, width: 600, height: 400)
    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)

    @MainActor
    private final class Trust {
        var isTrusted = true
    }

    @MainActor
    private struct Harness {
        let windows = FakeWindowController()
        let focused = FakeWindowController.makeRef(pid: ActionDispatcherDropTests.pid)
        let dragged = FakeWindowController.makeRef(pid: ActionDispatcherDropTests.pid, second: true)
        let trust: Trust
        let dispatcher: ActionDispatcher

        init(screens: [ScreenGeometry] = [FakeScreens.laptop], restoresSizeOnDragAway: Bool = true) {
            let trust = Trust()
            self.trust = trust
            dispatcher = ActionDispatcher(
                windows: windows,
                screens: FakeScreens(screens: screens),
                settings: { .defaults },
                isTrusted: { trust.isTrusted },
                frontmostPID: { ActionDispatcherDropTests.pid },
                isProcessRunning: { _ in true },
                retryDelay: .zero,
                restoresSizeOnDragAway: { restoresSizeOnDragAway }
            )
        }

        /// A focused window, and another window of the same app that the user dragged.
        func addWindows(draggedFrame: CGRect = ActionDispatcherDropTests.atDrop) async {
            await windows.add(focused, frame: CGRect(x: 800, y: 100, width: 400, height: 300))
            await windows.focus(focused)
            await windows.add(dragged, frame: draggedFrame)
        }

        func drop(
            _ action: WindowAction = .leftHalf,
            at frame: CGRect = ActionDispatcherDropTests.atDrop,
            from frameBeforeDrag: CGRect = ActionDispatcherDropTests.beforeDrag,
            on screen: ScreenGeometry = FakeScreens.laptop
        ) async {
            let window = DroppedWindow(
                pid: ActionDispatcherDropTests.pid,
                frameBeforeDrag: frameBeforeDrag,
                frame: frame
            )
            await dispatcher.perform(action, onDropped: window, on: screen).value
        }
    }

    @Test func snapsTheDroppedWindowNotTheFocusedOne() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.drop()
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.leftHalf)
        #expect(await harness.windows.frame(ofWindow: harness.focused) == CGRect(
            x: 800,
            y: 100,
            width: 400,
            height: 300
        ))
        #expect(await harness.windows.focusedWindowCalls == 0)
    }

    @Test func aWindowWithinTwoPointsOfTheDropStillMatches() async {
        let harness = Harness()
        await harness.addWindows(draggedFrame: Self.atDrop.offsetBy(dx: 2, dy: -2))
        await harness.drop()
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.leftHalf)
    }

    @Test func noMatchingWindowDoesNothing() async {
        let harness = Harness()
        await harness.addWindows(draggedFrame: Self.atDrop.offsetBy(dx: 40, dy: 0))
        await harness.drop()
        #expect(await harness.windows.setFrameCalls.isEmpty)
    }

    @Test func restoreAfterADropGoesBackToWhereTheDragStarted() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.drop()
        await harness.windows.focus(harness.dragged)
        await harness.dispatcher.perform(.restore).value
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.beforeDrag)
    }

    // Regression: the app's windows were searched in AX order, so a hidden native tab (its own window,
    // at the same frame) could be moved instead of the visible window.
    @Test func theMainWindowWinsOverAHiddenTabAtTheSameFrame() async {
        let harness = Harness()
        let tab = WindowRef(element: AXUIElementCreateApplication(Self.pid + 100), pid: Self.pid)
        await harness.windows.add(tab, frame: Self.atDrop)
        await harness.windows.add(harness.dragged, frame: Self.atDrop)
        await harness.windows.focus(harness.dragged)
        await harness.drop()
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.leftHalf)
        #expect(await harness.windows.frame(ofWindow: tab) == Self.atDrop)
    }

    @Test func anAppThatNudgedItsWindowAfterTheDropStillSnaps() async {
        let harness = Harness()
        await harness.windows.add(harness.dragged, frame: Self.atDrop.offsetBy(dx: 6, dy: 4))
        await harness.windows.focus(harness.dragged)
        await harness.drop()
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.leftHalf)
    }

    // Regression: the last fallback took the main window whenever its size matched, wherever it was,
    // so a ⌘-drag of a background window of the default size could snap the main window instead.
    @Test func aMainWindowOfTheSameSizeElsewhereIsNotSnapped() async {
        let harness = Harness()
        let elsewhere = CGRect(x: 800, y: 100, width: Self.atDrop.width, height: Self.atDrop.height)
        await harness.windows.add(harness.focused, frame: elsewhere)
        await harness.windows.focus(harness.focused)
        await harness.windows.add(harness.dragged, frame: Self.atDrop.offsetBy(dx: 40, dy: 0))
        await harness.drop()
        #expect(await harness.windows.frame(ofWindow: harness.focused) == elsewhere)
        #expect(await harness.windows.setFrameCalls.isEmpty)
    }

    @Test func restoreAfterReSnappingGoesBackToBeforeTheFirstSnap() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.drop()
        let moved = Self.leftHalf.offsetBy(dx: 600, dy: 0)
        try? await harness.windows.setFrame(moved, of: harness.dragged, sizeBeforeMove: nil)
        await harness.drop(.rightHalf, at: moved, from: Self.leftHalf)
        await harness.windows.focus(harness.dragged)
        await harness.dispatcher.perform(.restore).value
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.beforeDrag)
    }

    @Test(arguments: [FakeScreens.externalAbove, FakeScreens.portraitLeft])
    func snapsOnADisplayAboveOrLeftOfThePrimary(screen: ScreenGeometry) async {
        let harness = Harness(screens: [FakeScreens.laptop, screen])
        let dropped = CGRect(x: screen.frame.minX + 10, y: screen.frame.minY + 40, width: 600, height: 400)
        await harness.addWindows(draggedFrame: dropped)
        await harness.drop(at: dropped, on: screen)
        let expected = ActionCalculator.targetRect(for: .leftHalf, window: dropped, screen: screen, settings: .defaults)
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == expected)
        #expect(expected.map(screen.visibleFrame.contains) == true)
    }

    /// A half dropped onto the same half doesn't cycle to two-thirds: the drag has moved the window,
    /// so it no longer counts as snapped.
    @Test func droppingASnappedWindowOnTheSameHalfKeepsTheHalf() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.drop()
        let moved = Self.leftHalf.offsetBy(dx: 30, dy: 20)
        try? await harness.windows.setFrame(moved, of: harness.dragged, sizeBeforeMove: nil)
        await harness.drop(at: moved)
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.leftHalf)
    }

    /// A window dragged to the left edge of the display on the right is still mostly on the laptop.
    /// It snaps where the preview showed it, not on the display holding most of it.
    @Test func snapsOnTheDisplayItWasDroppedOn() async {
        let harness = Harness(screens: [FakeScreens.laptop, FakeScreens.externalRight])
        let straddling = CGRect(x: 1100, y: 100, width: 600, height: 400)
        await harness.addWindows(draggedFrame: straddling)
        await harness.drop(at: straddling, on: FakeScreens.externalRight)
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == CGRect(
            x: 1470,
            y: -217,
            width: 1280,
            height: 1415
        ))
    }

    // MARK: Busy apps and trust

    @Test func aBusyAppIsAskedOnceMore() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.windows.failWindowLookups(with: [.appNotResponding])
        await harness.drop()
        #expect(await harness.windows.windowLookups == 2)
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.leftHalf)
    }

    @Test func anAppStillBusyTheSecondTimeIsLeftAlone() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.windows.failWindowLookups(with: [.appNotResponding, .appNotResponding])
        await harness.drop()
        #expect(await harness.windows.windowLookups == 2)
        #expect(await harness.windows.setFrameCalls.isEmpty)
    }

    @Test func otherErrorsAreNotRetried() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.windows.failWindowLookups(with: [.elementGone])
        await harness.drop()
        #expect(await harness.windows.windowLookups == 1)
    }

    @Test func withoutAccessibilityNothingIsLookedUp() async {
        let harness = Harness()
        await harness.addWindows()
        harness.trust.isTrusted = false
        await harness.drop()
        #expect(await harness.windows.windowLookups == 0)
    }
}

// MARK: Restore the size on drag-away (PRD §6.3)

extension ActionDispatcherDropTests {
    /// Where the user drops the left-half window after dragging it away by its title bar.
    private static let draggedAway = CGRect(x: 300, y: 100, width: 735, height: 919)
    /// 20 % across its title bar.
    private static let grab = CGPoint(x: 447, y: 110)

    /// Snaps the dragged window to the left half by dropping it, then drags it to `frame`.
    private func snapThenDrag(_ harness: Harness, to frame: CGRect = draggedAway) async {
        await harness.addWindows()
        await harness.drop()
        try? await harness.windows.setFrame(frame, of: harness.dragged, sizeBeforeMove: nil)
    }

    private func dragAway(_ harness: Harness, to frame: CGRect = draggedAway, cursor: CGPoint = grab) async {
        let window = DroppedWindow(pid: Self.pid, frameBeforeDrag: Self.leftHalf, frame: frame)
        await harness.dispatcher.restoreSize(ofDropped: window, cursor: cursor).value
    }

    @Test func aSnappedWindowDraggedAwayGetsItsSizeBackUnderTheCursor() async {
        let harness = Harness()
        await snapThenDrag(harness)
        await dragAway(harness)
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == CGRect(
            x: 327,
            y: 100,
            width: 600,
            height: 400
        ))
    }

    @Test func afterADragAwayTheWindowIsForgotten() async {
        let harness = Harness()
        await snapThenDrag(harness)
        await dragAway(harness)
        #expect(!harness.dispatcher.rememberedWindows.contains(harness.dragged))
    }

    @Test func aWindowMullionNeverSnappedCostsNoAXCall() async {
        let harness = Harness()
        await harness.addWindows(draggedFrame: Self.draggedAway)
        await dragAway(harness)
        #expect(await harness.windows.windowLookups == 0)
        #expect(await harness.windows.setFrameCalls.isEmpty)
    }

    @Test func aWindowDroppedBackInPlaceStaysSnapped() async {
        let harness = Harness()
        let nearlyThere = Self.leftHalf.offsetBy(dx: 1, dy: 1)
        await snapThenDrag(harness, to: nearlyThere)
        let moves = await harness.windows.setFrameCalls.count
        await dragAway(harness, to: nearlyThere, cursor: CGPoint(x: 148, y: 48))
        #expect(await harness.windows.setFrameCalls.count == moves)
        #expect(harness.dispatcher.rememberedWindows.contains(harness.dragged))
    }

    /// A new window cascaded 22 pt from a snapped sibling has the same size, so the quick check by app
    /// passes; the decision still comes from the dropped window's own record, and it was never snapped.
    @Test func aCascadedSiblingOfASnappedWindowKeepsItsSize() async {
        let harness = Harness()
        await snapThenDrag(harness, to: Self.leftHalf)
        let sibling = WindowRef(element: AXUIElementCreateApplication(Self.pid + 200), pid: Self.pid)
        let cascaded = Self.leftHalf.offsetBy(dx: 22, dy: 22)
        let droppedAt = cascaded.offsetBy(dx: 300, dy: 50)
        await harness.windows.add(sibling, frame: droppedAt)
        await harness.windows.focus(sibling)
        let moves = await harness.windows.setFrameCalls.count
        let window = DroppedWindow(pid: Self.pid, frameBeforeDrag: cascaded, frame: droppedAt)
        await harness.dispatcher.restoreSize(
            ofDropped: window,
            cursor: CGPoint(x: droppedAt.minX + 100, y: droppedAt.minY + 10)
        ).value
        #expect(await harness.windows.frame(ofWindow: sibling) == droppedAt)
        #expect(await harness.windows.setFrameCalls.count == moves)
        #expect(await harness.windows.windowLookups == 2)
    }

    @Test func withTheSettingOffTheWindowKeepsItsSize() async {
        let harness = Harness(restoresSizeOnDragAway: false)
        await snapThenDrag(harness)
        await dragAway(harness)
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.draggedAway)
    }

    @Test func withoutAccessibilityTheWindowKeepsItsSize() async {
        let harness = Harness()
        await snapThenDrag(harness)
        harness.trust.isTrusted = false
        await dragAway(harness)
        #expect(await harness.windows.frame(ofWindow: harness.dragged) == Self.draggedAway)
    }
}
