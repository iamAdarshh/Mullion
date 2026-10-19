import ApplicationServices

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
        let app = application(pid)
        let value: CFTypeRef
        do {
            value = try copyAttribute(app, kAXFocusedWindowAttribute)
        } catch AXWindowError.attributeUnavailable {
            return nil
        }
        let window = try element(from: value)
        setTimeout(window)

        guard (try? string(window, kAXSubroleAttribute)) == kAXStandardWindowSubrole else { return nil }
        if (try? bool(window, fullScreenAttribute)) == true {
            return nil
        }
        return window
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

    /// Moves and resizes a window: size, then position, then size again (ARCHITECTURE §5.2).
    ///
    /// The first resize can be refused when the window would overflow its current screen, and the
    /// second one is needed after crossing displays. Apps with `AXEnhancedUserInterface` on (VoiceOver,
    /// some Electron and Chromium apps) animate or ignore resizes, so it is turned off for the move.
    ///
    /// - Throws: `AXWindowError.incompleteMove` when the window had already changed before the error.
    static func setFrame(_ frame: CGRect, of window: AXUIElement, pid: pid_t) throws {
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

        var changed = false
        if resizable {
            changed = logFailure("first resize") { try setSize(window, frame.size) }
        }
        do {
            try setPosition(window, frame.origin)
            changed = true
            if resizable {
                try setSize(window, frame.size)
            }
        } catch let error as AXWindowError where changed {
            throw AXWindowError.incompleteMove(error)
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
