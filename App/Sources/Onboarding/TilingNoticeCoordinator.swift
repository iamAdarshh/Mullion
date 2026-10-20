/// Tells the user, once per launch, when macOS's own tiling is on and conflicts with drag to snap
/// (PRD §6.6), until they choose *Don't Show Again*. If they open the settings and turn tiling off,
/// the next launch finds nothing to report.
@MainActor
final class TilingNoticeCoordinator {
    private let conflicts: () -> SystemTilingCheck.Conflicts
    private let isHidden: () -> Bool
    private let hide: () -> Void
    private let presenter: any TilingNoticePresenting
    private let openSettings: () -> Void
    private var hasShown = false

    /// - Parameters:
    ///   - conflicts: Reads the macOS tiling settings now.
    ///   - isHidden: Whether the user chose *Don't Show Again*; `hide` records that choice.
    ///   - openSettings: Opens *Desktop & Dock* in System Settings.
    init(
        conflicts: @escaping () -> SystemTilingCheck.Conflicts,
        isHidden: @escaping () -> Bool,
        hide: @escaping () -> Void,
        presenter: any TilingNoticePresenting,
        openSettings: @escaping () -> Void
    ) {
        self.conflicts = conflicts
        self.isHidden = isHidden
        self.hide = hide
        self.presenter = presenter
        self.openSettings = openSettings
    }

    /// Like `showIfNeeded()`, on the next turn of the run loop: the alert is modal, so it shouldn't run
    /// inside the launch sequence or a trust-change callback.
    func showLater() {
        Task { [weak self] in self?.showIfNeeded() }
    }

    /// Shows the notice if macOS tiling is on, unless it was already shown this launch or hidden for good.
    /// Call once Accessibility is granted, so it never covers the welcome window.
    func showIfNeeded() {
        guard !hasShown, !isHidden() else { return }
        let found = conflicts()
        guard !found.isEmpty else { return }
        hasShown = true
        Log.drag.info("macOS tiling is on (\(found.rawValue, privacy: .public)); showing the notice")
        presenter.present(found) { [weak self] choice in
            switch choice {
            case .openSettings: self?.openSettings()
            case .dontShowAgain: self?.hide()
            }
        }
    }
}
