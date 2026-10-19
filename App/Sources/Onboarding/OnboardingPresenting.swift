/// The welcome window as the coordinator sees it, so tests can swap in a fake.
@MainActor
protocol OnboardingPresenting: AnyObject {
    /// Called when the window closes, whether the user closed it or access was granted.
    var onClose: (() -> Void)? { get set }

    func present()
    func close()
}
