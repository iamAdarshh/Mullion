import MullionCore
import SwiftUI

/// The Drag tab (PRD §6.8): drag to snap on or off, the key that turns it off mid-drag, the size of
/// the snap areas and how the preview looks. Warns when macOS's own tiling is on (PRD §6.6).
struct DragSettingsView: View {
    @Bindable var preferences: Preferences
    let tiling: TilingStatus

    var body: some View {
        Form {
            if !conflicts.isEmpty {
                TilingWarning(conflicts: conflicts)
            }
            Section {
                Toggle("Snap windows dragged to a screen edge", isOn: $preferences.dragToSnapEnabled)
            }
            Group {
                Section {
                    Picker("Hold to move without snapping", selection: $preferences.snapModifier) {
                        ForEach(SnapModifier.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Edge size") {
                        SliderWithValue(
                            "Edge size",
                            value: $preferences.dragSettings.edgeThickness,
                            range: 1 ... 50,
                            step: 1
                        ) {
                            Text("\(Int($0)) pt", comment: "A size in points, for example 8 pt")
                        }
                    }
                    LabeledContent("Corner size") {
                        // Never smaller than the edge: starting the slider there shows the limit.
                        SliderWithValue(
                            "Corner size",
                            value: $preferences.dragSettings.cornerSize,
                            range: preferences.dragSettings.edgeThickness ... 100,
                            step: 1
                        ) {
                            Text("\(Int($0)) pt", comment: "A size in points, for example 8 pt")
                        }
                    }
                }
                Section("Preview") {
                    Toggle("Use accent colour", isOn: usesAccentColor)
                    if !usesAccentColor.wrappedValue {
                        ColorPicker("Colour", selection: previewColor, supportsOpacity: false)
                    }
                    LabeledContent("Opacity") {
                        SliderWithValue(
                            "Opacity",
                            value: $preferences.previewStyle.opacity,
                            range: PreviewStyle.opacityRange,
                            step: 0.05
                        ) {
                            Text($0, format: .percent.precision(.fractionLength(0)))
                        }
                    }
                    Toggle("Haptic feedback on Force Touch trackpads", isOn: $preferences.hapticFeedback)
                }
            }
            .disabled(!preferences.dragToSnapEnabled)
        }
        .settingsForm()
    }

    private var conflicts: SystemTilingCheck.Conflicts {
        preferences.relevantTilingConflicts(tiling.conflicts)
    }

    private var usesAccentColor: Binding<Bool> {
        Binding(
            get: { preferences.previewStyle.color == nil },
            set: { preferences.previewStyle.color = $0 ? nil : NSColor.controlAccentColor.usingColorSpace(.sRGB) }
        )
    }

    private var previewColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: preferences.previewStyle.resolvedColor) },
            set: { preferences.previewStyle.color = NSColor($0) }
        )
    }
}

/// The macOS tiling notice (PRD §6.6), inline, for as long as tiling stays on.
private struct TilingWarning: View {
    let conflicts: SystemTilingCheck.Conflicts

    var body: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 6) {
                    Text("macOS is also tiling windows").bold()
                    Text(TilingNoticeAlert.message(for: conflicts))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Desktop & Dock Settings") { TilingNoticeAlert.openSettings() }
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }
}
