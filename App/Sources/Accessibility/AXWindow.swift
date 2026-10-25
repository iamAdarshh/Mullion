import ApplicationServices
import MullionCore

/// Synchronous Accessibility calls on windows (ARCHITECTURE §5).
///
/// Every call is blocking IPC to another app, so only `AXQueue` calls these.
/// Every `AXError` is either thrown or logged; nothing is force-unwrapped.
enum AXWindow {
    /// How long to wait for an app before giving up (ARCHITECTURE §5.5).
    static let messagingTimeout: Float = 0.25

    private static let fullScreenAttribute = "AXFullScreen"
    private static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface"

    // MARK: Reading

    /// The focused standard window of the app with `pid`. `nil` when the app has no focused window,
    /// or it is the desktop, a full-screen window, or a non-standard window such as a panel (AC-3, AC-4).
    static func focusedWindow(pid: pid_t) throws -> AXUIElement? {
        try standardWindow(application(pid), kAXFocusedWindowAttribute)
    }

    /// The standard window of the app with `pid` that the user just dropped, found by its frame: the
    /// window server knows where it is, but there is no public way to turn its window number into an AX
    /// element (ADR-0003).
    ///
    /// 1. The main window, if its frame is within `tolerance` of `frame`. Dragging a window by its title
    ///    bar makes it the main window, so this is almost always the one, in one or two calls. It also
    ///    wins over a hidden native tab or another window at exactly the same frame.
    /// 2. Otherwise the first other standard window whose frame matches (a ⌘-drag of a background window).
    /// 3. Otherwise the main window if it has the same size and is within `nudgeTolerance` of the drop:
    ///    some apps nudge their window after a drop. Never a main window elsewhere on screen, which would
    ///    snap a window the user didn't drag.
    ///
    /// - Throws: `AXWindowError.appNotResponding` as soon as any read times out, so a busy app costs one
    ///   timeout rather than one per window, and the caller can ask again.
    static func window(pid: pid_t, matching frame: CGRect, tolerance: CGFloat) throws -> AXUIElement? {
        let app = application(pid)
        let main = try standardWindow(app, kAXMainWindowAttribute)
        let mainFrame = try main.flatMap { try readableFrame(of: $0) }
        if let main, let mainFrame, mainFrame.isApproximatelyEqual(to: frame, tolerance: tolerance) {
            return main
        }
        for window in try windows(of: app) where main.map({ !CFEqual($0, window) }) ?? true {
            guard let candidate = try readableFrame(of: window),
                  candidate.isApproximatelyEqual(to: frame, tolerance: tolerance),
                  isStandard(window)
            else { continue }
            return window
        }
        if let main, let mainFrame, isNudged(mainFrame, from: frame, tolerance: tolerance) {
            return main
        }
        Log.ax.debug("""
        No AX window at the drop \(String(describing: frame), privacy: .public); \
        main: \(String(describing: mainFrame), privacy: .public)
        """)
        return nil
    }

    /// The window's frame in AX space.
    static func frame(of window: AXUIElement) throws -> CGRect {
        let origin = try value(copyAttribute(window, kAXPositionAttribute), type: .cgPoint, initial: CGPoint.zero)
        let size = try value(copyAttribute(window, kAXSizeAttribute), type: .cgSize, initial: CGSize.zero)
        return CGRect(origin: origin, size: size)
    }

    /// `false` once the window has been closed.
    static func isAlive(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &value) != .invalidUIElement
    }

    // MARK: Writing

    /// Moves and resizes a window in `order` (ARCHITECTURE §5.2). Apps with `AXEnhancedUserInterface`
    /// on (VoiceOver, some Electron and Chromium apps) animate or ignore resizes, so it is turned off
    /// for the move.
    ///
    /// - Throws: `AXWindowError.incompleteMove` when the window had already changed before the error.
    static func setFrame(_ frame: CGRect, of window: AXUIElement, pid: pid_t, order: FrameWrite.Order) throws {
        // Fixed-size windows (Calculator) can only be moved. Asked before anything is written, so an
        // app that has stopped answering costs one timeout and the window is left untouched.
        var settable = DarwinBoolean(false)
        let resizable = try resizability(
            queryError: AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &settable),
            settable: settable.boolValue
        )

        let app = application(pid)
        let hadEnhancedUI = (try? bool(app, enhancedUserInterfaceAttribute)) == true
        if hadEnhancedUI {
            logFailure("disable enhanced UI") { try setBool(app, enhancedUserInterfaceAttribute, false) }
        }
        defer {
            if hadEnhancedUI {
                logFailure("restore enhanced UI") { try setBool(app, enhancedUserInterfaceAttribute, true) }
            }
        }

        try write(frame, order: order, resizable: resizable, to: ElementWriter(window: window))
    }

    /// The writes of `setFrame`. With `.sizeFirst`, the first resize may be refused while the window
    /// would overflow its current screen; the final one is needed after crossing displays.
    static func write(_ frame: CGRect, order: FrameWrite.Order, resizable: Bool, to window: some FrameWriting) throws {
        var changed = false
        if resizable, order == .sizeFirst {
            changed = logFailure("first resize") { try window.setSize(frame.size) }
        }
        do {
            try window.setPosition(frame.origin)
            changed = true
            if resizable {
                try window.setSize(frame.size)
            }
        } catch let error as AXWindowError where changed {
            throw AXWindowError.incompleteMove(error)
        }
        if resizable {
            resizeAgainIfCutShort(frame, window)
        }
    }

    /// How `setFrame` treats the answer to "is the size settable?".
    ///
    /// A timeout aborts the move before anything is written: the app is busy, and every further call
    /// would cost another timeout on the serial `AXQueue`. Any other error means "move only", as for a
    /// fixed-size window, because the final resize would fail too and abort the move halfway.
    static func resizability(queryError: AXError, settable: Bool) throws -> Bool {
        switch queryError {
        case .success:
            return settable
        case .cannotComplete:
            throw AXWindowError.appNotResponding
        default:
            Log.ax.debug("Can't tell if the size is settable: \(queryError.rawValue, privacy: .public)")
            return false
        }
    }

    // MARK: Private

    /// `FrameWriting` for a real window.
    private struct ElementWriter: FrameWriting {
        let window: AXUIElement

        func setSize(_ size: CGSize) throws {
            try AXWindow.setSize(window, size)
        }

        func setPosition(_ origin: CGPoint) throws {
            try AXWindow.setPosition(window, origin)
        }

        func frame() throws -> CGRect {
            try AXWindow.frame(of: window)
        }
    }

    /// Some apps cut a resize short or drop it (#16). A window smaller than `frame` fits at its origin,
    /// so position then size can't overflow, and is asked for once more. Best effort: the caller reads
    /// the frame back anyway, and treats a size the app still keeps like a minimum size.
    private static func resizeAgainIfCutShort(_ frame: CGRect, _ window: some FrameWriting) {
        guard let actual = try? window.frame(), FrameWrite.wasCutShort(actual.size, target: frame.size) else { return }
        let got = String(describing: actual)
        let wanted = String(describing: frame)
        Log.ax.debug("Resize cut short at \(got, privacy: .public) for \(wanted, privacy: .public); asking again")
        logFailure("resize again") {
            try window.setPosition(frame.origin)
            try window.setSize(frame.size)
        }
    }

    /// The window in `attribute` of `app` (main or focused), if it is a standard window.
    private static func standardWindow(_ app: AXUIElement, _ attribute: String) throws -> AXUIElement? {
        let value: CFTypeRef
        do {
            value = try copyAttribute(app, attribute)
        } catch AXWindowError.attributeUnavailable {
            return nil
        }
        let window = try element(from: value)
        setTimeout(window)
        return isStandard(window) ? window : nil
    }

    /// Every window of `app`, with the messaging timeout set.
    private static func windows(of app: AXUIElement) throws -> [AXUIElement] {
        let value: CFTypeRef
        do {
            value = try copyAttribute(app, kAXWindowsAttribute)
        } catch AXWindowError.attributeUnavailable {
            return []
        }
        guard let items = value as? [CFTypeRef] else { throw AXWindowError.unexpectedValueType }
        return items.compactMap { item in
            guard let window = try? element(from: item) else { return nil }
            setTimeout(window)
            return window
        }
    }

    /// The window's frame, or `nil` when this one window can't say (it closed, or has no frame).
    /// Rethrows a timeout or a revoked trust: every further call would fail the same way.
    private static func readableFrame(of window: AXUIElement) throws -> CGRect? {
        do {
            return try frame(of: window)
        } catch let error as AXWindowError where error == .appNotResponding || error == .notTrusted {
            throw error
        } catch {
            return nil
        }
    }

    /// How far an app may nudge its window after a drop and still be the window that was dropped.
    static let nudgeTolerance: CGFloat = 30

    /// Whether `window` is the dropped window at `frame`, moved a little by its app: the same size,
    /// within `tolerance`, and an origin within `nudgeTolerance`.
    static func isNudged(_ window: CGRect, from frame: CGRect, tolerance: CGFloat) -> Bool {
        abs(window.width - frame.width) <= tolerance && abs(window.height - frame.height) <= tolerance
            && hypot(window.minX - frame.minX, window.minY - frame.minY) <= nudgeTolerance
    }

    /// A standard window that isn't full screen: the only kind Mullion moves (AC-3).
    private static func isStandard(_ window: AXUIElement) -> Bool {
        guard (try? string(window, kAXSubroleAttribute)) == kAXStandardWindowSubrole else { return false }
        return (try? bool(window, fullScreenAttribute)) != true
    }

    private static func application(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        setTimeout(app)
        return app
    }

    private static func setTimeout(_ element: AXUIElement) {
        logFailure("set messaging timeout") {
            try AXUIElementSetMessagingTimeout(element, messagingTimeout).check()
        }
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) throws -> CFTypeRef {
        var value: CFTypeRef?
        try AXUIElementCopyAttributeValue(element, attribute as CFString, &value).check()
        guard let value else { throw AXWindowError.attributeUnavailable }
        return value
    }

    private static func element(from value: CFTypeRef) throws -> AXUIElement {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { throw AXWindowError.unexpectedValueType }
        // swiftlint:disable:next force_cast
        return value as! AXUIElement // Safe: the CFGetTypeID check above guarantees the type.
    }

    private static func value<T>(_ value: CFTypeRef, type: AXValueType, initial: T) throws -> T {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { throw AXWindowError.unexpectedValueType }
        // swiftlint:disable:next force_cast
        let axValue = value as! AXValue // Safe: the CFGetTypeID check above guarantees the type.
        var result = initial
        guard AXValueGetType(axValue) == type, AXValueGetValue(axValue, type, &result) else {
            throw AXWindowError.unexpectedValueType
        }
        return result
    }

    private static func string(_ element: AXUIElement, _ attribute: String) throws -> String {
        guard let string = try copyAttribute(element, attribute) as? String else {
            throw AXWindowError.unexpectedValueType
        }
        return string
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) throws -> Bool {
        guard let bool = try copyAttribute(element, attribute) as? Bool else { throw AXWindowError.unexpectedValueType }
        return bool
    }

    private static func setBool(_ element: AXUIElement, _ attribute: String, _ value: Bool) throws {
        try AXUIElementSetAttributeValue(element, attribute as CFString, value as CFBoolean).check()
    }

    private static func setPosition(_ window: AXUIElement, _ origin: CGPoint) throws {
        var point = origin
        guard let value = AXValueCreate(.cgPoint, &point) else { throw AXWindowError.valueEncoding }
        try AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value).check()
    }

    private static func setSize(_ window: AXUIElement, _ size: CGSize) throws {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { throw AXWindowError.valueEncoding }
        try AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value).check()
    }

    /// Runs a step whose failure isn't fatal to the move, logging the error instead of throwing it.
    /// Returns whether the step succeeded.
    @discardableResult
    private static func logFailure(_ step: StaticString, _ body: () throws -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            Log.ax.debug("AX step '\(step, privacy: .public)' failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
