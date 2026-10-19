import SwiftUI

/// The welcome window's content: explains why Accessibility access is needed (PRD §6.9.1).
struct OnboardingView: View {
    let onRequestAccess: () -> Void

    @State private var hasRequested = false

    /// The first click shows the macOS alert; later clicks open System Settings directly
    /// (see `PermissionMonitor.requestTrust()`), so the label says what happens next.
    /// Typed as `LocalizedStringKey` because a ternary of plain literals would infer `String`
    /// and skip the String Catalog.
    private var buttonTitle: LocalizedStringKey {
        hasRequested ? "Open System Settings" : "Grant Access…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Allow Mullion to arrange your windows")
                    .font(.title2.bold())
            }

            Text(
                // swiftlint:disable:next line_length
                "Mullion uses the macOS Accessibility permission to read and change the position and size of other apps' windows. It doesn't read what's inside your windows and never sends anything over the network."
            )
            .fixedSize(horizontal: false, vertical: true)

            Text(
                // swiftlint:disable:next line_length
                "Turn on Mullion in System Settings → Privacy & Security → Accessibility. Mullion continues automatically as soon as access is granted."
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                if hasRequested {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for access…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(buttonTitle) {
                    hasRequested = true
                    onRequestAccess()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
