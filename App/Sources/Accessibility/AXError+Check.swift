import ApplicationServices

extension AXError {
    /// Throws an `AXWindowError` unless the call succeeded.
    func check() throws {
        guard self == .success else { throw AXWindowError(self) }
    }
}
