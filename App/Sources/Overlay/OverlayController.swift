import AppKit
import MullionCore
import QuartzCore

/// The drag-to-snap preview: a translucent rect over the screen the window will snap on (PRD §6.4).
///
/// One click-through panel per screen, created or moved into place when a window drag starts and
/// reused across drags (ARCHITECTURE §6). The panel never takes focus or clicks, so the drag
/// underneath is unaffected. Moving between areas slides the preview to its new rect; with Reduce
/// motion on, it jumps there instead. Showing and hiding always fade (NFR-4).
@MainActor
final class OverlayController: SnapPreviewing {
    private static let fadeDuration: TimeInterval = 0.12
    private static let slideDuration: TimeInterval = 0.15

    private let style: () -> PreviewStyle

    private var panels: [String: PreviewPanel] = [:]
    private var visibleScreenID: String?
    /// Read with the screens at drag start, so panel frames and the screens agree for the whole drag.
    private var space: CoordinateSpace?

    /// `style` is read on every preview, so a change in Settings shows on the next drag.
    init(style: @escaping () -> PreviewStyle = { PreviewStyle() }) {
        self.style = style
    }

    func prepare(for screens: [ScreenGeometry]) {
        space = Self.primarySpace()
        let ids = Set(screens.map(\.id))
        for (id, panel) in panels where !ids.contains(id) {
            panel.close()
            panels[id] = nil
            if visibleScreenID == id {
                visibleScreenID = nil
            }
        }
        for screen in screens {
            _ = panel(for: screen)
        }
    }

    func show(_ rect: CGRect, on screen: ScreenGeometry) {
        if let visibleScreenID, visibleScreenID != screen.id {
            panels[visibleScreenID]?.fadeOut(duration: Self.fadeDuration)
        }
        guard let panel = panel(for: screen) else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let wasVisible = visibleScreenID == screen.id
        // The view is flipped, so the screen-local AX rect places the preview directly.
        panel.preview(
            screen.localRect(rect),
            style: style(),
            slide: wasVisible && !reduceMotion,
            duration: Self.slideDuration
        )
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

    /// The panel covering `screen`, created or moved into place if needed. `nil` with no screens at all.
    private func panel(for screen: ScreenGeometry) -> PreviewPanel? {
        guard let space = space ?? Self.primarySpace() else { return nil }
        let frame = space.appKitRect(fromAX: screen.frame)
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

    private static func primarySpace() -> CoordinateSpace? {
        // The primary screen (with the menu bar) is the flip reference (ARCHITECTURE §4).
        NSScreen.screens.first.map { CoordinateSpace(primaryScreenHeight: $0.frame.height) }
    }
}

/// A borderless, click-through panel covering one screen, holding the preview layer.
@MainActor
private final class PreviewPanel: NSPanel {
    /// Where a fade-in starts, so the very first frame already shows the preview (AC-5).
    private static let fadeInStartAlpha: CGFloat = 0.5

    private let previewLayer = CALayer()
    /// Counts fades. A fade-out only orders the panel out if no fade started after it.
    private var fadeGeneration = 0

    init(frame: CGRect) {
        // Not deferred: the window-server backing is made now, at drag start, not on the first preview.
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
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
    func preview(_ rect: CGRect, style: PreviewStyle, slide: Bool, duration: TimeInterval) {
        let color = style.resolvedColor
        CATransaction.begin()
        CATransaction.setDisableActions(!slide)
        CATransaction.setAnimationDuration(duration)
        previewLayer.frame = rect
        previewLayer.backgroundColor = color.withAlphaComponent(style.opacity).cgColor
        previewLayer.borderColor = color.withAlphaComponent(style.borderOpacity).cgColor
        CATransaction.commit()
    }

    func fadeIn(duration: TimeInterval) {
        fadeGeneration += 1
        alphaValue = max(alphaValue, Self.fadeInStartAlpha)
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 1
        }
    }

    func fadeOut(duration: TimeInterval) {
        fadeGeneration += 1
        let generation = fadeGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // A preview may have faded the panel back in meanwhile.
                if self?.fadeGeneration == generation {
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
