import ApplicationServices

/// Why an Accessibility call failed, in terms the rest of the app can act on.
enum AXWindowError: Error, Equatable {
    /// Mullion isn't trusted for Accessibility (`kAXErrorAPIDisabled`).
    case notTrusted
    /// The window or app no longer exists (`kAXErrorInvalidUIElement`).
    case elementGone
    /// The app didn't answer within the messaging timeout, or is busy (`kAXErrorCannotComplete`).
    case appNotResponding
    /// The element has no such attribute, or no value for it right now.
    case attributeUnavailable
    /// An attribute held a value of an unexpected CF type.
    case unexpectedValueType
    /// `AXValueCreate` couldn't wrap a point or size.
    case valueEncoding
    /// Any other `AXError`, kept by raw value for logging.
    case other(code: Int32)

    init(_ error: AXError) {
        switch error {
        case .apiDisabled: self = .notTrusted
        case .invalidUIElement: self = .elementGone
        case .cannotComplete: self = .appNotResponding
        case .attributeUnsupported, .noValue: self = .attributeUnavailable
        default: self = .other(code: error.rawValue)
        }
    }
}
