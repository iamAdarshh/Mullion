import CoreGraphics

/// The writes `AXWindow.setFrame` makes to one window, kept apart from AX so their order can be
/// tested against a simulated window. All frames are in AX space.
protocol FrameWriting {
    func setSize(_ size: CGSize) throws
    func setPosition(_ origin: CGPoint) throws
    func size() throws -> CGSize
}
