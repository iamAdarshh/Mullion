import Testing
@testable import Mullion

struct SystemTilingCheckTests {
    private typealias Key = SystemTilingCheck

    private func check(_ values: [String: any Sendable], hasSystemTiling: Bool = true) -> SystemTilingCheck.Conflicts {
        SystemTilingCheck(hasSystemTiling: hasSystemTiling, value: { values[$0] }).conflicts()
    }

    private static let allOff: [String: any Sendable] = [
        Key.edgeTilingKey: false, Key.topEdgeTilingKey: false, Key.optionTilingKey: false,
    ]

    /// Settings the user never changed are missing from the domain, and macOS has them on.
    @Test func untouchedSettingsAreOn() {
        #expect(check([:]) == [.edgeTiling, .optionTiling])
    }

    @Test func allOffIsNoConflict() {
        #expect(check(Self.allOff).isEmpty)
    }

    @Test(arguments: [SystemTilingCheck.edgeTilingKey, SystemTilingCheck.topEdgeTilingKey])
    func eitherEdgeSettingIsEdgeTiling(key: String) {
        var values = Self.allOff
        values[key] = true
        #expect(check(values) == .edgeTiling)
    }

    @Test func holdOptionToTileOnItsOwn() {
        var values = Self.allOff
        values[Key.optionTilingKey] = true
        #expect(check(values) == .optionTiling)
    }

    /// The domain stores booleans as numbers.
    @Test func numbersCountAsBooleans() {
        let values: [String: any Sendable] = [Key.edgeTilingKey: 0, Key.topEdgeTilingKey: 1, Key.optionTilingKey: 0]
        #expect(check(values) == .edgeTiling)
    }

    @Test func macOS14HasNoTiling() {
        #expect(check([:], hasSystemTiling: false).isEmpty)
    }

    struct RelevantCase: Sendable {
        let dragToSnap: Bool
        let modifier: SnapModifier
        let expected: SystemTilingCheck.Conflicts
    }

    /// ⌥-drag tiling only clashes while ⌥ is Mullion's modifier, and nothing clashes with drag to
    /// snap off (PRD §6.6). The launch notice and Settings → Drag both use this.
    @Test(arguments: [
        RelevantCase(dragToSnap: true, modifier: .option, expected: [.edgeTiling, .optionTiling]),
        RelevantCase(dragToSnap: true, modifier: .control, expected: [.edgeTiling]),
        RelevantCase(dragToSnap: false, modifier: .option, expected: []),
        RelevantCase(dragToSnap: false, modifier: .control, expected: []),
    ])
    func relevantConflicts(_ test: RelevantCase) {
        let all: SystemTilingCheck.Conflicts = [.edgeTiling, .optionTiling]
        #expect(all.relevant(dragToSnap: test.dragToSnap, snapModifier: test.modifier) == test.expected)
    }
}
