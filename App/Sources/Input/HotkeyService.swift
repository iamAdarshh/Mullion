import KeyboardShortcuts
import MullionCore

/// Registers a global hotkey for every action.
///
/// KeyboardShortcuts uses Carbon `RegisterEventHotKey`, so no Input Monitoring permission is needed,
/// and the key press is consumed: the frontmost app never sees it and nothing beeps (AC-4).
@MainActor
final class HotkeyService {
    private let onAction: (WindowAction) -> Void

    init(onAction: @escaping (WindowAction) -> Void) {
        self.onAction = onAction
    }

    func start() {
        for action in WindowAction.allCases {
            KeyboardShortcuts.onKeyDown(for: DefaultShortcuts.name(for: action)) { [weak self] in
                Log.hotkey.debug("Hotkey for \(action.rawValue, privacy: .public)")
                self?.onAction(action)
            }
        }
        Log.hotkey.info("Registered hotkeys for \(WindowAction.allCases.count, privacy: .public) actions")
    }
}
