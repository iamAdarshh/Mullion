import ServiceManagement
@testable import Mullion

@MainActor
final class FakeLoginItemService: LoginItemService {
    struct Failure: Error {}

    var status: SMAppService.Status = .notRegistered
    var fails = false
    /// The status `register()` leaves behind, for example `.requiresApproval`.
    var statusAfterRegister: SMAppService.Status = .enabled

    func register() throws {
        if fails {
            throw Failure()
        }
        status = statusAfterRegister
    }

    func unregister() throws {
        if fails {
            throw Failure()
        }
        status = .notRegistered
    }
}
