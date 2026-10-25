import CoreGraphics
import MullionCore
import Testing
@testable import Mullion

@MainActor
struct ActionDispatcherTests {
    private static let pid: pid_t = 4242
    private static let floating = CGRect(x: 100, y: 200, width: 600, height: 300)
    private static let leftHalf = CGRect(x: 0, y: 37, width: 735, height: 919)

    /// What the dispatcher asks the outside world: trust and the frontmost app.
    @MainActor
    private final class Environment {
        var isTrusted = true
        var checks = 0
        var frontmostPID: pid_t?
        var quitPIDs: Set<pid_t> = []

        init(frontmostPID: pid_t?) {
            self.frontmostPID = frontmostPID
        }
    }

    @MainActor
    private struct Harness {
        let windows = FakeWindowController()
        let window = FakeWindowController.makeRef(pid: ActionDispatcherTests.pid)
        let trust: Environment
        let dispatcher: ActionDispatcher

        init(
            screens: [ScreenGeometry] = [FakeScreens.laptop],
            settings: ActionSettings = .defaults,
            frontmost: pid_t? = ActionDispatcherTests.pid
        ) {
            let trust = Environment(frontmostPID: frontmost)
            self.trust = trust
            dispatcher = ActionDispatcher(
                windows: windows,
                screens: FakeScreens(screens: screens),
                settings: { settings },
                isTrusted: {
                    trust.checks += 1
                    return trust.isTrusted
                },
                frontmostPID: { trust.frontmostPID },
                isProcessRunning: { !trust.quitPIDs.contains($0) }
            )
        }

        func addFocusedWindow(
            frame: CGRect = ActionDispatcherTests.floating,
            minimumSize: CGSize = .zero,
            isResizable: Bool = true
        ) async {
            await windows.add(window, frame: frame, minimumSize: minimumSize, isResizable: isResizable)
            await windows.focus(window)
        }

        func perform(_ actions: WindowAction...) async {
            for action in actions {
                await dispatcher.perform(action).value
            }
        }

        /// Focuses a window of a different app and makes that app frontmost.
        func switchToAnotherApp() async -> WindowRef {
            let pid = ActionDispatcherTests.pid + 1
            let other = FakeWindowController.makeRef(pid: pid)
            await windows.add(other, frame: ActionDispatcherTests.floating)
            await windows.focus(other)
            trust.frontmostPID = pid
            return other
        }

        var frame: CGRect? {
            get async { await windows.frame(ofWindow: window) }
        }
    }

    // MARK: Basics

    @Test func movesTheFocusedWindow() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf)

        #expect(await harness.frame == Self.leftHalf)
    }

    @Test func noFocusedWindowDoesNothing() async {
        let harness = Harness()
        await harness.windows.add(harness.window, frame: Self.floating)

        await harness.perform(.leftHalf)

        #expect(await harness.windows.setFrameCalls.isEmpty)
    }

    @Test func mullionAsTheFrontmostAppDoesNothing() async {
        let harness = Harness(frontmost: nil)
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf)

        #expect(await harness.windows.focusedWindowCalls == 0)
    }

    // MARK: Accessibility trust (PRD §6.9.3)

    @Test func everyActionChecksTrustFirst() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf, .rightHalf)

        #expect(harness.trust.checks == 2)
    }

    @Test func untrustedActionsMakeNoAXCalls() async {
        let harness = Harness()
        harness.trust.isTrusted = false
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf)

        #expect(await harness.windows.focusedWindowCalls == 0)
        #expect(await harness.frame == Self.floating)
    }

    // MARK: Repeat to cycle (PRD §6.2)

    @Test func repeatingAHalfCyclesItsSize() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf, .leftHalf)
        #expect(await harness.frame?.width == 980)

        await harness.perform(.leftHalf)
        #expect(await harness.frame?.width == 490)

        await harness.perform(.leftHalf)
        #expect(await harness.frame?.width == 735)
    }

    @Test func actionsQueuedWithoutWaitingStillRunInOrder() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        harness.dispatcher.perform(.leftHalf)
        await harness.dispatcher.perform(.leftHalf).value

        #expect(await harness.frame?.width == 980)
    }

    // MARK: Restore (PRD §6.3)

    @Test func restoreGoesBackToTheFrameBeforeTheFirstMove() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf, .maximize, .restore)

        #expect(await harness.frame == Self.floating)
    }

    @Test func restoreIsForgottenOnceUsed() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf, .restore)
        let callsAfterRestore = await harness.windows.setFrameCalls.count
        await harness.perform(.restore)

        #expect(await harness.windows.setFrameCalls.count == callsAfterRestore)
        #expect(harness.dispatcher.rememberedWindows.isEmpty)
    }

    @Test func restoreWithoutAnEarlierMoveDoesNothing() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        await harness.perform(.restore)

        #expect(await harness.windows.setFrameCalls.isEmpty)
    }

    @Test func closedWindowsOfTheSameAppAreForgotten() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.perform(.leftHalf)

        // The first window closes; then another window of the same app is snapped.
        let sibling = FakeWindowController.makeRef(pid: Self.pid, second: true)
        await harness.windows.close(harness.window)
        await harness.windows.add(sibling, frame: Self.floating)
        await harness.windows.focus(sibling)
        await harness.perform(.leftHalf)

        #expect(harness.dispatcher.rememberedWindows == [sibling])
    }

    @Test func windowsOfQuitAppsAreForgottenWithoutAXCalls() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.perform(.leftHalf)

        let other = await harness.switchToAnotherApp()
        harness.trust.quitPIDs = [Self.pid]
        await harness.perform(.leftHalf)

        #expect(harness.dispatcher.rememberedWindows == [other])
        #expect(await harness.windows.isAliveCalls.contains(Self.pid) == false)
    }

    /// Regression: cleanup used to query every remembered window over AX after each action,
    /// so one frozen app added up to 0.25 s per window to every later hotkey.
    @Test func windowsOfOtherRunningAppsAreNeverQueried() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.perform(.leftHalf)

        let other = await harness.switchToAnotherApp()
        await harness.perform(.leftHalf, .rightHalf)

        #expect(await harness.windows.isAliveCalls.contains(Self.pid) == false)
        #expect(Set(harness.dispatcher.rememberedWindows) == [harness.window, other])
    }

    // MARK: Minimum and fixed sizes (AC-2)

    @Test func windowWithAMinimumSizeIsReanchoredOnScreen() async {
        let harness = Harness()
        await harness.addFocusedWindow(minimumSize: CGSize(width: 800, height: 400))

        await harness.perform(.rightHalf)

        // The app keeps 800 pt; the window is moved left so it doesn't spill off the screen.
        #expect(await harness.frame == CGRect(x: 670, y: 37, width: 800, height: 919))
    }

    @Test func fixedSizeWindowIsOnlyMoved() async {
        let harness = Harness()
        await harness.addFocusedWindow(isResizable: false)

        await harness.perform(.rightHalf)

        #expect(await harness.frame == CGRect(x: 735, y: 37, width: 600, height: 300))
    }

    @Test func snapRecordUsesTheFrameTheWindowEndedUpWith() async {
        let harness = Harness()
        await harness.addFocusedWindow(minimumSize: CGSize(width: 800, height: 400))

        // Second press must still count as a repeat, although the window isn't exactly half width.
        await harness.perform(.rightHalf, .rightHalf)

        #expect(await harness.frame?.width == 980)
    }

    /// Regression: the minimum-size correction used to pull a window that spans two displays onto
    /// one screen, undoing Grow's promise to keep it where it is.
    @Test func growOnAWindowSpanningDisplaysStaysPutWhenTheAppKeepsADifferentSize() async {
        let harness = Harness(screens: [FakeScreens.laptop, FakeScreens.externalRight])
        let spanning = CGRect(x: 1000, y: 200, width: 1000, height: 300)
        await harness.addFocusedWindow(frame: spanning, minimumSize: CGSize(width: 1100, height: 0))

        await harness.perform(.larger)

        #expect(await harness.frame == CGRect(x: 1000, y: 170, width: 1100, height: 360))
    }

    /// Regression (#16): resizing a right-half window to the full width in place stretched it past the
    /// screen edge, where an app cut the resize short, then dropped the final one.
    @Test func topHalfAfterRightHalfShrinksTheWindowBeforeMovingIt() async {
        let harness = Harness()
        await harness.addFocusedWindow()

        await harness.perform(.rightHalf, .topHalf)

        #expect(await harness.windows.sizesBeforeMove.last == CGSize(width: 735, height: 460))
        #expect(await harness.frame == CGRect(x: 0, y: 37, width: 1470, height: 460))
    }

    // MARK: Displays (PRD §6.5)

    @Test func nextDisplayKeepsTheSnappedAction() async {
        let harness = Harness(screens: [FakeScreens.laptop, FakeScreens.externalRight])
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf, .nextDisplay)

        #expect(await harness.frame == CGRect(x: 1470, y: -217, width: 1280, height: 1415))
    }

    // MARK: Errors

    @Test func aFailureThatChangedNothingIsForgotten() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.windows.failSetFrame(with: .appNotResponding)

        await harness.perform(.leftHalf)

        #expect(await harness.frame == Self.floating)
        #expect(harness.dispatcher.rememberedWindows.isEmpty)
    }

    /// Regression: a failed action used to clear the snap record, so the next press restarted the
    /// cycle at ½ instead of moving on to ⅔.
    @Test func aFailedRepeatKeepsTheCycleGoing() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.perform(.leftHalf)

        await harness.windows.failSetFrame(with: .appNotResponding)
        await harness.perform(.leftHalf)
        await harness.windows.failSetFrame(with: nil)
        await harness.perform(.leftHalf)

        #expect(await harness.frame?.width == 980)
    }

    /// Regression: the restore frame used to be saved only after every AX step succeeded, so a window
    /// that was resized before the app timed out could never be restored.
    @Test func aMoveThatFailsHalfwayCanStillBeRestored() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.windows.failSetFrame(with: .appNotResponding, afterResizing: true)
        await harness.perform(.leftHalf)
        #expect(await harness.frame != Self.floating)

        await harness.windows.failSetFrame(with: nil)
        await harness.perform(.restore)

        #expect(await harness.frame == Self.floating)
    }
}
