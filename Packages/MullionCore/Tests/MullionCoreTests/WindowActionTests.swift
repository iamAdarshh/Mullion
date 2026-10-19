import Testing
@testable import MullionCore

struct WindowActionTests {
    /// Raw values are persisted in configs and shortcut storage. Changing one is a breaking change
    /// that needs a migration, so this list is deliberately spelled out.
    @Test func rawValuesAreStable() {
        #expect(WindowAction.allCases.map(\.rawValue) == [
            "leftHalf", "rightHalf", "topHalf", "bottomHalf",
            "topLeft", "topRight", "bottomLeft", "bottomRight",
            "firstThird", "centerThird", "lastThird", "firstTwoThirds", "lastTwoThirds",
            "topLeftSixth", "topCenterSixth", "topRightSixth",
            "bottomLeftSixth", "bottomCenterSixth", "bottomRightSixth",
            "maximize", "almostMaximize", "maximizeHeight", "center", "larger", "smaller", "restore",
            "nextDisplay", "previousDisplay",
        ])
    }

    @Test func groupsFollowTheMenuOrder() {
        let groups = WindowAction.Group.allCases.map { group in
            WindowAction.allCases.filter { $0.group == group }.count
        }
        #expect(WindowAction.Group.allCases == [.halves, .quarters, .thirds, .sixths, .other, .displays])
        #expect(groups == [4, 4, 5, 6, 7, 2])
    }

    @Test(arguments: [WindowAction.leftHalf, .rightHalf, .topHalf, .bottomHalf])
    func halvesCycle(action: WindowAction) {
        #expect(action.isHalf)
    }

    @Test(arguments: WindowAction.allCases.filter { $0.group != .halves })
    func otherActionsDoNotCycle(action: WindowAction) {
        #expect(!action.isHalf)
    }
}
