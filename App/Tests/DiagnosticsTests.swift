import CoreGraphics
import MullionCore
import Testing
@testable import Mullion

struct DiagnosticsTests {
    private static let diagnostics = Diagnostics(
        appVersion: "1.0.0 (12)",
        bundleID: "io.github.iamadarshh.mullion",
        macOSVersion: "15.1 (24B83)",
        isTrusted: false,
        screens: [
            ScreenGeometry(
                id: "A",
                frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
                visibleFrame: CGRect(x: 0, y: 37, width: 1710, height: 1075),
                scale: 2
            ),
            ScreenGeometry(
                id: "B",
                frame: CGRect(x: -865, y: -1440, width: 3440, height: 1440),
                visibleFrame: CGRect(x: -865, y: -1440, width: 3440, height: 1440),
                scale: 1
            ),
        ],
        tilingConflicts: [.optionTiling],
        config: MullionConfig(general: .init(gap: 8), ignoredBundleIDs: ["com.example.secret", "com.apple.Notes"])
    )

    @Test func describesTheSetup() {
        let report = Self.diagnostics.report
        #expect(report.contains("Mullion 1.0.0 (12) (io.github.iamadarshh.mullion)"))
        #expect(report.contains("Accessibility: missing"))
        #expect(report.contains("  1: 1710×1112 pt at (0, 0), @2x, primary"))
        #expect(report.contains("  2: 3440×1440 pt at (-865, -1440), @1x"))
        #expect(report.contains("macOS tiling: edge off, ⌥ on"))
        #expect(report.contains(#""gap" : 8"#))
    }

    /// Bug reports are public: the ignored apps are counted, never named.
    @Test func countsIgnoredAppsWithoutNamingThem() {
        let report = Self.diagnostics.report
        #expect(report.contains("Ignored apps: 2"))
        #expect(!report.contains("com.example.secret"))
        #expect(!report.contains("ignoredBundleIDs"))
    }
}
