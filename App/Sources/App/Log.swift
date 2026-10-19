import Foundation
import os

/// One `Logger` per subsystem area. Stream them with:
/// `log stream --predicate 'subsystem BEGINSWITH "io.github.iamadarshh.mullion"' --level debug`
///
/// Never log window titles or contents above `.debug` (REVIEW.md).
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "io.github.iamadarshh.mullion"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let ax = Logger(subsystem: subsystem, category: "ax")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let drag = Logger(subsystem: subsystem, category: "drag")
    static let layout = Logger(subsystem: subsystem, category: "layout")
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
