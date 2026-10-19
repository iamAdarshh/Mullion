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
                frontmostPID: { trust.frontmostPID }
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

    @Test func closedWindowsAreForgotten() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.perform(.leftHalf)

        // The first window closes; then a window of another app is snapped.
        let other = FakeWindowController.makeRef(pid: Self.pid + 1)
        await harness.windows.close(harness.window)
        await harness.windows.add(other, frame: Self.floating)
        await harness.windows.focus(other)
        harness.trust.frontmostPID = Self.pid + 1
        await harness.perform(.leftHalf)

        #expect(harness.dispatcher.rememberedWindows == [other])
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

    // MARK: Displays (PRD §6.5)

    @Test func nextDisplayKeepsTheSnappedAction() async {
        let harness = Harness(screens: [FakeScreens.laptop, FakeScreens.externalRight])
        await harness.addFocusedWindow()

        await harness.perform(.leftHalf, .nextDisplay)

        #expect(await harness.frame == CGRect(x: 1470, y: -217, width: 1280, height: 1415))
    }

    // MARK: Errors

    @Test func axErrorsAreSwallowedAndNothingIsRemembered() async {
        let harness = Harness()
        await harness.addFocusedWindow()
        await harness.windows.failSetFrame(with: .appNotResponding)

        await harness.perform(.leftHalf)

        #expect(await harness.frame == Self.floating)
        #expect(harness.dispatcher.rememberedWindows.isEmpty)
    }
}
