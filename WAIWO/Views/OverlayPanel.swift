import AppKit

final class OverlayPanel: NSPanel {
    var isInputMode = false
    var onCancel: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { isInputMode }
    override var canBecomeMain: Bool { isInputMode }

    override func cancelOperation(_ sender: Any?) {
        if isInputMode {
            onCancel?()
        }
    }
}
