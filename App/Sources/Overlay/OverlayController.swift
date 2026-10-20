import AppKit
import MullionCore
import QuartzCore

/// The drag-to-snap preview: a translucent rect over the screen the window will snap on (PRD §6.4).
///
/// One click-through panel per screen, created the first time it's needed and reused afterwards
/// (ARCHITECTURE §6). The panel never takes focus or clicks, so the drag underneath is unaffected.
/// Moving between areas slides the preview to its new rect; with Reduce motion on, it fades instead.
@MainActor
final class OverlayController: SnapPreviewing {
    private static let fadeDuration: TimeInterval = 0.12
    private static let slideDuration: TimeInterval = 0.15

    private var panels: [String: PreviewPanel] = [:]
    private var visibleScreenID: String?

    func show(_ rect: CGRect, on screen: ScreenGeometry) {
        if let visibleScreenID, visibleScreenID != screen.id {
            panels[visibleScreenID]?.fadeOut(duration: Self.fadeDuration)
        }
        let panel = panel(for: screen)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // The preview is placed relative to the screen's top-left in AX space; the view is flipped to match.
        let local = rect.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        let wasVisible = visibleScreenID == screen.id
        panel.preview(local, slide: wasVisible && !reduceMotion, duration: Self.slideDuration)
        if !wasVisible {
            panel.fadeIn(duration: Self.fadeDuration)
        }
        visibleScreenID = screen.id
    }

    func hide() {
        guard let visibleScreenID else { return }
        panels[visibleScreenID]?.fadeOut(duration: Self.fadeDuration)
        self.visibleScreenID = nil
    }

    private func panel(for screen: ScreenGeometry) -> PreviewPanel {
        // The primary screen (with the menu bar) is the flip reference (ARCHITECTURE §4).
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let frame = CoordinateSpace(primaryScreenHeight: primaryHeight).appKitRect(fromAX: screen.frame)
        if let panel = panels[screen.id] {
            if panel.frame != frame {
                panel.setFrame(frame, display: false)
            }
            return panel
        }
        let panel = PreviewPanel(frame: frame)
        panels[screen.id] = panel
        return panel
    }
}

/// A borderless, click-through panel covering one screen, holding the preview layer.
@MainActor
private final class PreviewPanel: NSPanel {
    private let previewLayer = CALayer()

    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        alphaValue = 0

        let view = FlippedView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        // Decorative: VoiceOver has nothing to announce while the user drags.
        view.setAccessibilityElement(false)
        previewLayer.cornerRadius = 10
        previewLayer.borderWidth = 2
        view.layer?.addSublayer(previewLayer)
        contentView = view
    }

    /// Moves the preview to `rect`, in the view's flipped coordinates.
    func preview(_ rect: CGRect, slide: Bool, duration: TimeInterval) {
        // Read the accent colour each time: the user can change it while Mullion runs.
        let accent = NSColor.controlAccentColor
        CATransaction.begin()
        CATransaction.setDisableActions(!slide)
        CATransaction.setAnimationDuration(duration)
        previewLayer.frame = rect
        previewLayer.backgroundColor = accent.withAlphaComponent(0.2).cgColor
        previewLayer.borderColor = accent.withAlphaComponent(0.6).cgColor
        CATransaction.commit()
    }

    func fadeIn(duration: TimeInterval) {
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 1
        }
    }

    func fadeOut(duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // A new preview may have faded the panel back in meanwhile.
            MainActor.assumeIsolated {
                if self?.alphaValue == 0 {
                    self?.orderOut(nil)
                }
            }
        }
    }
}

/// Top-left origin, so the preview can be placed with AX-space offsets and no y-flip.
private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
