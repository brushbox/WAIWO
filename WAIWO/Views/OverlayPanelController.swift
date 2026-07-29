import AppKit
import SwiftUI

/// Thin adapter over the NSPanel: swaps SwiftUI content, applies layouts
/// produced by the reducer, and handles show/hide fades. Owns no layout
/// decisions — frame and opacity always arrive as an `OverlayLayout`.
@MainActor
final class OverlayPanelController {
    private let panel: OverlayPanel
    private let todoState: TodoState
    private var hostingView: NSHostingView<OverlayContentView>?
    private var inputActive = false

    var isVisible: Bool { panel.isVisible }

    init(todoState: TodoState) {
        self.todoState = todoState
        self.panel = OverlayPanel(contentRect: NSRect(x: 100, y: 100, width: 400, height: 60))
        setupContent()
    }

    private func setupContent() {
        let content = OverlayContentView(
            displayState: todoState.displayState,
            upcomingTodos: todoState.upcomingTodos,
            hasLinks: !todoState.currentLinks.isEmpty,
            staleDateText: todoState.staleDateText
        )
        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView
        self.hostingView = hostingView
        applyRoundedCorners()
    }

    private func applyRoundedCorners() {
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true
    }

    func updateContent() {
        let content = OverlayContentView(
            displayState: todoState.displayState,
            upcomingTodos: todoState.upcomingTodos,
            hasLinks: !todoState.currentLinks.isEmpty,
            staleDateText: todoState.staleDateText
        )
        hostingView?.rootView = content
        panel.invalidateShadow()
    }

    func apply(_ layout: OverlayLayout) {
        switch layout.animation {
        case .none:
            panel.setFrame(layout.frame, display: true, animate: false)
            panel.alphaValue = layout.opacity
        case .move:
            panel.alphaValue = layout.opacity
            panel.setFrame(layout.frame, display: true, animate: true)
        case .fade:
            if panel.frame != layout.frame {
                panel.setFrame(layout.frame, display: true, animate: false)
            }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = layout.opacity
            }
        }
        panel.invalidateShadow()
    }

    func presentInput(mode: InputView.Mode, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        guard !inputActive else { return }
        inputActive = true

        panel.onCancel = onCancel

        NSApp.activate(ignoringOtherApps: true)
        panel.isInputMode = true
        panel.makeKey()

        let input = InputView(mode: mode, onSubmit: onSubmit, onCancel: onCancel)
        panel.contentView = NSHostingView(rootView: input)
        applyRoundedCorners()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.focusTextInput()
        }
    }

    private func focusTextInput() {
        guard let contentView = panel.contentView else { return }

        func findTextInput(in view: NSView) -> NSView? {
            if let tv = view as? NSTextView, tv.isEditable { return tv }
            if let tf = view as? NSTextField, tf.isEnabled { return tf }
            for subview in view.subviews {
                if let found = findTextInput(in: subview) { return found }
            }
            return nil
        }

        if let textInput = findTextInput(in: contentView) {
            panel.makeFirstResponder(textInput)
        }
    }

    func dismissInputContent() {
        guard inputActive else { return }
        inputActive = false
        panel.isInputMode = false
        panel.onCancel = nil
        panel.resignKey()
        panel.contentView = hostingView
        applyRoundedCorners()
        panel.invalidateShadow()
    }

    func show(targetOpacity: CGFloat, completion: @escaping () -> Void) {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = targetOpacity
        }, completionHandler: completion)
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }
}
