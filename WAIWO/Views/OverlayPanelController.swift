import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private let panel: OverlayPanel
    private let todoState: TodoState
    private var hostingView: NSHostingView<OverlayContentView>?
    private var inputHostingView: NSHostingView<InputView>?
    private var isInputMode = false

    var isVisible: Bool { panel.isVisible }

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
        panel.isInputMode = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        panel.invalidateShadow()
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
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1.0
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