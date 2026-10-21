import MullionCore
import SwiftUI

/// The General tab (PRD §6.8): startup and the menu bar icon, how actions size windows, and what
/// happens on repeat and drag-away.
struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences
    let loginItem: LoginItem

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(get: { loginItem.isEnabled }, set: loginItem.setEnabled))
                if loginItem.needsApproval {
                    LabeledContent {
                        Button("Open Login Items Settings") { loginItem.openSystemSettings() }
                    } label: {
                        Text("Mullion is turned off in Login Items.")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $preferences.showsMenuBarIcon) {
                    Text("Show in menu bar")
                    if !preferences.showsMenuBarIcon {
                        Text("To get back to Settings, open Mullion again from the Applications folder.")
                    }
                }
            }
            Section {
                Picker("Repeating a half shortcut", selection: $preferences.actionSettings.repeatBehavior) {
                    Text("Cycle ½, ⅔, ⅓").tag(ActionSettings.RepeatBehavior.cycleSizes)
                    Text("Move to next display").tag(ActionSettings.RepeatBehavior.moveToNextDisplay)
                    Text("Do nothing").tag(ActionSettings.RepeatBehavior.doNothing)
                }
                LabeledContent("Gap between windows") {
                    SliderWithValue(
                        "Gap between windows",
                        value: $preferences.actionSettings.gap,
                        range: 0 ... 40,
                        step: 1
                    ) {
                        Text("\(Int($0)) pt", comment: "A size in points, for example 8 pt")
                    }
                }
                LabeledContent("Almost Maximize size") {
                    SliderWithValue(
                        "Almost Maximize size",
                        value: $preferences.actionSettings.almostMaximizeFraction,
                        range: 0.5 ... 1,
                        step: 0.01
                    ) {
                        Text($0, format: .percent.precision(.fractionLength(0)))
                    }
                }
                LabeledContent("Grow and Shrink step") {
                    HStack {
                        Text("\(Int(preferences.actionSettings.resizeStep)) pt")
                            .monospacedDigit()
                        Stepper(
                            "Grow and Shrink step",
                            value: $preferences.actionSettings.resizeStep,
                            in: 5 ... 200,
                            step: 5
                        )
                        .labelsHidden()
                    }
                }
            }
            Section {
                Toggle(
                    "Restore a snapped window's size when it's dragged away",
                    isOn: $preferences.restoresSizeOnDragAway
                )
            }
        }
        .settingsForm()
    }
}
