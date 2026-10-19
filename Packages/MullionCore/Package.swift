// swift-tools-version: 6.0
import PackageDescription

/// Pure geometry and decision logic for Mullion. Foundation + CoreGraphics only:
/// no AppKit, no ApplicationServices, no third-party dependencies (ADR-0004, ADR-0005).
let package = Package(
    name: "MullionCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MullionCore", targets: ["MullionCore"]),
    ],
    targets: [
        .target(name: "MullionCore"),
        .testTarget(name: "MullionCoreTests", dependencies: ["MullionCore"]),
    ],
    swiftLanguageModes: [.v6]
)
