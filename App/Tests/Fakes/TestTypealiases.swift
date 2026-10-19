@testable import Mullion

/// Carbon (pulled in by KeyboardShortcuts) also declares a `WindowRef`. Inside the app target
/// Mullion's own type wins; in the test module both are visible, so pick Mullion's explicitly.
typealias WindowRef = Mullion.WindowRef
