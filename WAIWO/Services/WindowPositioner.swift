import AppKit
import Foundation

enum PositionerLogic {
    private static let cursorRepulsionThreshold: CGFloat = 150
    private static let gridStep: CGFloat = 100

    static func bestPosition(
        screenBounds: CGRect,
        overlaySize: CGSize,
        focusedWindowFrame: CGRect?,
        cursorPosition: CGPoint
    ) -> CGPoint {
        var candidates: [(CGPoint, CGFloat)] = []

        let minX = screenBounds.minX
        let maxX = screenBounds.maxX - overlaySize.width
        let minY = screenBounds.minY
        let maxY = screenBounds.maxY - overlaySize.height

        guard maxX >= minX, maxY >= minY else {
            return CGPoint(x: screenBounds.minX, y: screenBounds.minY)
        }

        var x = minX
        while x <= maxX {
            var y = minY
            while y <= maxY {
                let point = CGPoint(x: x, y: y)
                let score = scorePosition(
                    point: point,
                    overlaySize: overlaySize,
                    focusedWindowFrame: focusedWindowFrame,
                    cursorPosition: cursorPosition
                )
                candidates.append((point, score))
                y += gridStep
            }
            x += gridStep
        }

        let corners: [CGPoint] = [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: maxX, y: maxY),
        ]
        for corner in corners {
            let score = scorePosition(
                point: corner,
                overlaySize: overlaySize,
                focusedWindowFrame: focusedWindowFrame,
                cursorPosition: cursorPosition
            )
            candidates.append((corner, score))
        }

        return candidates.max(by: { $0.1 < $1.1 })?.0
            ?? CGPoint(x: minX, y: minY)
    }

    private static func scorePosition(
        point: CGPoint,
        overlaySize: CGSize,
        focusedWindowFrame: CGRect?,
        cursorPosition: CGPoint
    ) -> CGFloat {
        let overlayCenter = CGPoint(
            x: point.x + overlaySize.width / 2,
            y: point.y + overlaySize.height / 2
        )

        var score: CGFloat = 0

        if let fwf = focusedWindowFrame {
            let fwCenter = CGPoint(x: fwf.midX, y: fwf.midY)
            let dist = hypot(overlayCenter.x - fwCenter.x, overlayCenter.y - fwCenter.y)
            score += dist * 2.0

            let overlayRect = CGRect(origin: point, size: overlaySize)
            if overlayRect.intersects(fwf) {
                score -= 5000
            }
        }

        let cursorDist = hypot(overlayCenter.x - cursorPosition.x, overlayCenter.y - cursorPosition.y)
        score += cursorDist

        if cursorDist < cursorRepulsionThreshold {
            score -= (cursorRepulsionThreshold - cursorDist) * 10
        }

        return score
    }
}

final class WindowPositioner {
    private let panelController: OverlayPanelController
    private var timer: Timer?
    private var mouseMonitor: Any?
    private var workspaceObserver: Any?
    private var currentCursorPosition: CGPoint = .zero
    private var focusedWindowFrame: CGRect?
    private var focusedWindowScreen: NSScreen?
    private var isPaused: Bool = false

    init(panelController: OverlayPanelController) {
        self.panelController = panelController
    }

    func start() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.currentCursorPosition = NSEvent.mouseLocation
        }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            self?.reposition()
        }

        if !AccessibilityHelper.hasPermission {
            AccessibilityHelper.requestPermission()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        focusedWindowFrame = AccessibilityHelper.focusedWindowFrame(for: app)

        if let frame = focusedWindowFrame {
            focusedWindowScreen = NSScreen.screens.first { screen in
                screen.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
            }
        }
    }

    private func reposition() {
        guard !isPaused, panelController.isVisible else { return }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let targetScreen: NSScreen
        if screens.count > 1, let fwScreen = focusedWindowScreen {
            targetScreen = screens.first { $0 != fwScreen } ?? screens[0]
        } else {
            targetScreen = screens[0]
        }

        let overlaySize = panelController.window.frame.size
        let bestPoint = PositionerLogic.bestPosition(
            screenBounds: targetScreen.visibleFrame,
            overlaySize: overlaySize,
            focusedWindowFrame: (targetScreen == focusedWindowScreen) ? focusedWindowFrame : nil,
            cursorPosition: currentCursorPosition
        )

        let targetFrame = NSRect(origin: bestPoint, size: overlaySize)
        let currentFrame = panelController.window.frame

        let lerp: CGFloat = 0.15
        let newX = currentFrame.origin.x + (targetFrame.origin.x - currentFrame.origin.x) * lerp
        let newY = currentFrame.origin.y + (targetFrame.origin.y - currentFrame.origin.y) * lerp
        let smoothFrame = NSRect(origin: CGPoint(x: newX, y: newY), size: overlaySize)

        panelController.setFrame(smoothFrame, animate: false)
    }

    deinit {
        stop()
    }
}
