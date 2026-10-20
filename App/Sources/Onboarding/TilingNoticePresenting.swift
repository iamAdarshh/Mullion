/// The tiling notice as `TilingNoticeCoordinator` sees it, so tests can swap in a fake.
@MainActor
protocol TilingNoticePresenting {
    /// Shows the notice for `conflicts` and calls `completion` with the user's choice.
    func present(_ conflicts: SystemTilingCheck.Conflicts, completion: @escaping (TilingNoticeChoice) -> Void)
}

/// What the user chose in the tiling notice.
enum TilingNoticeChoice: Equatable {
    case openSettings
    case dontShowAgain
}
