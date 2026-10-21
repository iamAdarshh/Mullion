import Foundation
import Observation
import ServiceManagement

/// What `LoginItem` needs from `SMAppService`, so tests can use a fake.
@MainActor
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Launch at login (PRD §6.8 General), through `SMAppService.mainApp`. macOS owns the setting and
/// shows it in System Settings → General → Login Items, where the user can also change it, so the
/// state is read from the service instead of being stored in `Preferences`.
@MainActor
@Observable
final class LoginItem {
    /// The last state read from macOS. `.requiresApproval` means the user turned Mullion off in
    /// Login Items; registering again doesn't override that.
    /// `SMAppService.Status` raw values: 0 not registered, 1 enabled, 2 requires approval, 3 not found.
    private(set) var status: SMAppService.Status
    @ObservationIgnored private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        status = service.status
    }

    /// On for the toggle: registered, even while it waits for approval in System Settings.
    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    /// Re-reads the state, which the user may have changed in System Settings.
    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Log.settings.error(
                "Couldn't turn launch at login \(enabled ? "on" : "off", privacy: .public): \(error, privacy: .public)"
            )
        }
        refresh()
        let status = status.rawValue
        Log.settings
            .info("Launch at login \(enabled ? "on" : "off", privacy: .public): status \(status, privacy: .public)")
    }

    /// Opens System Settings → General → Login Items.
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
