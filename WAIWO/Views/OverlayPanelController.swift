import AppKit
import SwiftUI

final class OverlayPanelController {
    private let panel: OverlayPanel
    private let todoState: TodoState
    private var hostingView: NSHostingView<OverlayContentView>?

    var isVisible: Bool { panel.isVisible }

    var window: NSPanel { panel }

    init(todoState: TodoState) {
        self.todoState = todoState
        self.panel = OverlayPanel(contentRect: NSRect(x: 100, y: 100, width: 450, height: 60))
        setupContent()
    }

    private func setupContent() {
        let content = OverlayContentView(
            displayState: todoState.displayState,
            staleDateText: todoState.staleDateText
        )
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)
        self.hostingView = hostingView
    }

    func updateContent() {
        let content = OverlayContentView(
            displayState: todoState.displayState,
            staleDateText: todoState.staleDateText
        )
        hostingView?.rootView = content
        panel.invalidateShadow()
    }

    func show() {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1.0
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    func setFrame(_ frame: NSRect, animate: Bool) {
        panel.setFrame(frame, display: true, animate: animate)
    }

    /// Fade out, move to new position, fade in
    func fadeToFrame(_ frame: NSRect) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.setFrame(frame, display: true, animate: false)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                self?.panel.animator().alphaValue = 1.0
            }
        })
    }
}
