import SwiftUI

/// A slider followed by its current value, so the user can see the exact number. The slider keeps
/// the row's label for VoiceOver. It rounds to `step` itself: a slider given a `step` draws a tick
/// mark for every one.
struct SliderWithValue<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
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
