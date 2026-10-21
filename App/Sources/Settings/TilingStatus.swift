import Observation

/// The macOS tiling settings that clash with drag to snap, for the Drag tab (PRD §6.6). Checked again
/// whenever the Settings window comes to the front, so turning tiling off in System Settings clears
/// the warning on return.
@MainActor
@Observable
final class TilingStatus {
    private(set) var conflicts: SystemTilingCheck.Conflicts = []
    @ObservationIgnored private let check: () -> SystemTilingCheck.Conflicts

    init(check: @escaping () -> SystemTilingCheck.Conflicts) {
        self.check = check
        refresh()
    }

    func refresh() {
        conflicts = check()
    }
}
