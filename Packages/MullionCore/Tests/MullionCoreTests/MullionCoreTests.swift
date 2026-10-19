import Testing
@testable import MullionCore

struct MullionCoreTests {
    @Test func configSchemaVersionStartsAtOne() {
        #expect(MullionCore.configSchemaVersion == 1)
    }
}
