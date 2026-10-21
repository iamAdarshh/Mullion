import ServiceManagement
import Testing
@testable import Mullion

@MainActor
struct LoginItemTests {
    private let service = FakeLoginItemService()

    @Test func startsFromWhatMacOSReports() {
        service.status = .enabled
        #expect(LoginItem(service: service).isEnabled)
    }

    @Test func turningItOnAndOff() {
        let item = LoginItem(service: service)
        item.setEnabled(true)
        #expect(item.isEnabled)
        item.setEnabled(false)
        #expect(!item.isEnabled)
        #expect(item.status == .notRegistered)
    }

    /// Turned off in System Settings → Login Items: still on for the toggle, but flagged.
    @Test func waitingForApprovalCountsAsOn() {
        service.statusAfterRegister = .requiresApproval
        let item = LoginItem(service: service)
        item.setEnabled(true)
        #expect(item.isEnabled)
        #expect(item.needsApproval)
    }

    @Test func aFailureLeavesTheRealState() {
        service.fails = true
        let item = LoginItem(service: service)
        item.setEnabled(true)
        #expect(!item.isEnabled)
    }

    @Test func refreshPicksUpChangesMadeInSystemSettings() {
        let item = LoginItem(service: service)
        service.status = .enabled
        item.refresh()
        #expect(item.isEnabled)
    }
}
