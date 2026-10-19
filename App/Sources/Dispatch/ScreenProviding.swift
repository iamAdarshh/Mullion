import MullionCore

/// The connected displays, in AX space. `SystemScreens` is the live implementation.
@MainActor
protocol ScreenProviding {
    var screens: [ScreenGeometry] { get }
}
