import Testing
@testable import Mullion

@MainActor
struct TilingStatusTests {
    @Test func readsOnCreationAndOnRefresh() {
        var current: SystemTilingCheck.Conflicts = [.edgeTiling, .optionTiling]
        let status = TilingStatus { current }
        #expect(status.conflicts == [.edgeTiling, .optionTiling])
        current = []
        status.refresh()
        #expect(status.conflicts.isEmpty)
    }
}
