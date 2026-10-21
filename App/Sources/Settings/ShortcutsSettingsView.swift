import KeyboardShortcuts
import MullionCore
import SwiftUI

/// The Shortcuts tab (PRD §6.8): a recorder for every action, grouped as in the menu. Changes apply
/// at once, and the menu bar shows the new shortcuts too.
struct ShortcutsSettingsView: View {
    /// Taller than the screen if it fitted all 22 actions, so this tab scrolls.
    private static let height: CGFloat = 520

    @State private var isConfirmingReset = false

    var body: some View {
        Form {
            ForEach(WindowAction.Group.allCases, id: \.self) { group in
                Section(group.title) {
                    ForEach(WindowAction.allCases.filter { $0.group == group }, id: \.self) { action in
                        LabeledContent(action.title) {
                            KeyboardShortcuts.Recorder(for: DefaultShortcuts.name(for: action))
                                .shortcutValidation { ShortcutConflicts.validate($0, for: action) }
                                .accessibilityLabel(Text(action.title))
                        }
                    }
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Restore Defaults…") { isConfirmingReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: Self.height)
        .confirmationDialog("Restore the default shortcuts?", isPresented: $isConfirmingReset) {
            Button("Restore Defaults", role: .destructive) {
                KeyboardShortcuts.reset(WindowAction.allCases.map(DefaultShortcuts.name(for:)))
            }
        } message: {
            Text("Every shortcut you changed goes back to its default.")
        }
    }
}
