import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private let panel: OverlayPanel
    private let todoState: TodoState
    private var hostingView: NSHostingView<OverlayContentView>?
    private var inputHostingView: NSHostingView<InputView>?
    private var isInputMode = false
    private(set) var isAnimatingOpacity = false
    private(set) var proximityOpacity: CGFloat = 1.0

    var isVisible: Bool { panel.isVisible }
    var isInputModeActive: Bool { isInputMode }

    var window: NSPanel { panel }

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

    func showInput(mode: InputView.Mode, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        isInputMode = true

        panel.onCancel = { [weak self] in
            self?.dismissInput()
            onCancel()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.isInputMode = true
        panel.makeKey()

        let input = InputView(
            mode: mode,
            onSubmit: { [weak self] text in
                self?.dismissInput()
                onSubmit(text)
            },
            onCancel: { [weak self] in
                self?.dismissInput()
                onCancel()
            }
        )
        let hostingView = NSHostingView(rootView: input)
        inputHostingView = hostingView
        panel.contentView = hostingView
        applyRoundedCorners()

        let inputHeight: CGFloat = mode == .todo ? 80 : 160
        let newFrame = NSRect(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y - (inputHeight - panel.frame.height),
            width: 400,
            height: inputHeight
        )
        panel.setFrame(newFrame, display: true, animate: true)
        panel.invalidateShadow()

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

    func dismissInput() {
        guard isInputMode else { return }
        isInputMode = false
        panel.isInputMode = false
        panel.onCancel = nil
        panel.resignKey()
        inputHostingView = nil
        panel.contentView = hostingView
        applyRoundedCorners()

        let displayHeight: CGFloat = 60
        let newFrame = NSRect(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y + (panel.frame.height - displayHeight),
            width: 400,
            height: displayHeight
        )
        panel.setFrame(newFrame, display: true, animate: true)
        panel.invalidateShadow()
    }

    func show() {
        isAnimatingOpacity = true
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = proximityOpacity
        }, completionHandler: { [weak self] in
            self?.isAnimatingOpacity = false
        })
    }

    func setProximityOpacity(_ opacity: CGFloat, animated: Bool) {
        guard !isAnimatingOpacity, !isInputMode, panel.isVisible else { return }
        proximityOpacity = opacity
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = opacity
            }
        } else {
            panel.alphaValue = opacity
        }
    }

    func hide() {
        if isInputMode {
            dismissInput()
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    func setFrame(_ frame: NSRect, animate: Bool) {
        guard !isInputMode else { return }
        panel.setFrame(frame, display: true, animate: animate)
    }

    func fadeToFrame(_ frame: NSRect) {
        guard !isInputMode else { return }
        panel.setFrame(frame, display: true, animate: false)
    }
}