import AppKit

/// Entry point. Mullion is an AppKit menu bar agent (`LSUIElement`), so there is no SwiftUI `App` scene.
@main
enum MullionApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // `NSApplication.delegate` is weak; keep ours alive for the life of the run loop.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
