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

        init(screens: [ScreenGeometry] = [FakeScreens.laptop]) {
            let trust = Trust()
            self.trust = trust
            dispatcher = ActionDispatcher(
                windows: windows,
                screens: FakeScreens(screens: screens),
                settings: { .defaults },
                isTrusted: { trust.isTrusted },
                frontmostPID: { ActionDispatcherDropTests.pid },
                isProcessRunning: { _ in true },
                retryDelay: .zero
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
            on screen: ScreenGeometry = FakeScreens.laptop
        ) async {
            let window = DroppedWindow(pid: ActionDispatcherDropTests.pid, frameBeforeDrag: beforeDrag, frame: frame)
            await dispatcher.perform(action, onDropped: window, on: screen).value
        }

        private var beforeDrag: CGRect {
            ActionDispatcherDropTests.beforeDrag
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

    /// A half dropped onto the same half doesn't cycle to two-thirds: the drag has moved the window,
    /// so it no longer counts as snapped.
    @Test func droppingASnappedWindowOnTheSameHalfKeepsTheHalf() async {
        let harness = Harness()
        await harness.addWindows()
        await harness.drop()
        let moved = Self.leftHalf.offsetBy(dx: 30, dy: 20)
        try? await harness.windows.setFrame(moved, of: harness.dragged)
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
