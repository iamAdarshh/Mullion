import AppKit

/// The key that, held during a drag, moves the window without snapping (PRD §6.4, §6.8 Drag).
/// ⇧ is kept for Zones (v2) and ⌘ is macOS's own gesture for dragging background windows.
enum SnapModifier: String, CaseIterable {
    case option
    case control

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .option: .option
        case .control: .control
        }
    }

    var title: String {
        switch self {
        case .option: String(localized: "⌥ Option", comment: "The Option key")
        case .control: String(localized: "⌃ Control", comment: "The Control key")
        }
    }
}
