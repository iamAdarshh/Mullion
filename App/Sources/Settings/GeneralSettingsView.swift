import MullionCore
import SwiftUI

/// The General tab (PRD §6.8): how actions size windows, and what happens on repeat and drag-away.
struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            Section {
                Picker("Repeating a half shortcut", selection: $preferences.actionSettings.repeatBehavior) {
                    Text("Cycle ½, ⅔, ⅓").tag(ActionSettings.RepeatBehavior.cycleSizes)
                    Text("Move to next display").tag(ActionSettings.RepeatBehavior.moveToNextDisplay)
                    Text("Do nothing").tag(ActionSettings.RepeatBehavior.doNothing)
                }
                LabeledContent("Gap between windows") {
                    SliderWithValue(value: $preferences.actionSettings.gap, range: 0 ... 40, step: 1) {
                        Text("\(Int($0)) pt", comment: "A size in points, for example 8 pt")
                    }
                }
                LabeledContent("Almost Maximize size") {
                    SliderWithValue(
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

/// A slider followed by its current value, so the user can see the exact number. The slider keeps
/// the row's label for VoiceOver. It rounds to `step` itself: a slider given a `step` draws a tick
/// mark for every one.
private struct SliderWithValue<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value
    let label: (Value) -> Text

    init(
        value: Binding<Value>,
        range: ClosedRange<Value>,
        step: Value,
        @ViewBuilder label: @escaping (Value) -> Text
    ) {
        _value = value
        self.range = range
        self.step = step
        self.label = label
    }

    var body: some View {
        HStack {
            Slider(value: rounded, in: range)
            label(value)
                .monospacedDigit()
                .frame(minWidth: 44, alignment: .trailing)
        }
    }

    private var rounded: Binding<Value> {
        Binding(
            get: { value },
            set: { value = ($0 / step).rounded() * step }
        )
    }
}

extension View {
    /// The look every Settings tab shares: grouped sections, sized to fit their content.
    func settingsForm() -> some View {
        formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
    }
}
