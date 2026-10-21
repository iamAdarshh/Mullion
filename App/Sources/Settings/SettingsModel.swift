/// Everything the Settings tabs show and change.
@MainActor
struct SettingsModel {
    let preferences: Preferences
    let loginItem: LoginItem
    let tiling: TilingStatus

    /// Re-reads what the user can change outside Mullion, in System Settings.
    func refresh() {
        loginItem.refresh()
        tiling.refresh()
    }
}
