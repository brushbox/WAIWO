import AppKit
import Foundation

enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

enum PositionerLogic {
    private static let cursorRepulsionThreshold: CGFloat = 150
    private static let edgeInsetFraction: CGFloat = 0.10

    /// Pick the best corner on the given screen, avoiding the focused window and cursor.
    static func bestCorner(
        screenBounds: CGRect,
        overlaySize: CGSize,
        focusedWindowFrame: CGRect?,
        cursorPosition: CGPoint
    ) -> (corner: Corner, origin: CGPoint) {
        let candidates = Corner.allCases.map { corner in
            let origin = originForCorner(corner, screenBounds: screenBounds, overlaySize: overlaySize)
            let score = scoreCorner(origin: origin, overlaySize: overlaySize, focusedWindowFrame: focusedWindowFrame, cursorPosition: cursorPosition)
            return (corner, origin, score)
        }
        let best = candidates.max(by: { $0.2 < $1.2 })!
        return (best.0, best.1)
    }

    static func bestPosition(
        screenBounds: CGRect,
        overlaySize: CGSize,
        focusedWindowFrame: CGRect?,
        cursorPosition: CGPoint
    ) -> CGPoint {
        bestCorner(screenBounds: screenBounds, overlaySize: overlaySize, focusedWindowFrame: focusedWindowFrame, cursorPosition: cursorPosition).origin
    }

    static func originForCorner(_ corner: Corner, screenBounds: CGRect, overlaySize: CGSize) -> CGPoint {
        let padX = screenBounds.width * edgeInsetFraction
        let padY = screenBounds.height * edgeInsetFraction
        switch corner {
        case .topLeft:
            return CGPoint(x: screenBounds.minX + padX, y: screenBounds.maxY - overlaySize.height - padY)
        case .topRight:
            return CGPoint(x: screenBounds.maxX - overlaySize.width - padX, y: screenBounds.maxY - overlaySize.height - padY)
        case .bottomLeft:
            return CGPoint(x: screenBounds.minX + padX, y: screenBounds.minY + padY)
        case .bottomRight:
            return CGPoint(x: screenBounds.maxX - overlaySize.width - padX, y: screenBounds.minY + padY)
        }
    }

    private static func scoreCorner(
        origin: CGPoint,
        overlaySize: CGSize,
        focusedWindowFrame: CGRect?,
        cursorPosition: CGPoint
    ) -> CGFloat {
        let overlayCenter = CGPoint(
            x: origin.x + overlaySize.width / 2,
            y: origin.y + overlaySize.height / 2
        )

        var score: CGFloat = 0

        // Distance from focused window (higher is better)
        if let fwf = focusedWindowFrame {
            let fwCenter = CGPoint(x: fwf.midX, y: fwf.midY)
            let dist = hypot(overlayCenter.x - fwCenter.x, overlayCenter.y - fwCenter.y)
            score += dist * 2.0

            // Big penalty for overlapping
            let overlayRect = CGRect(origin: origin, size: overlaySize)
            if overlayRect.intersects(fwf) {
                score -= 5000
            }
        }

        // Distance from cursor (higher is better)
        let cursorDist = hypot(overlayCenter.x - cursorPosition.x, overlayCenter.y - cursorPosition.y)
        score += cursorDist

        if cursorDist < cursorRepulsionThreshold {
            score -= (cursorRepulsionThreshold - cursorDist) * 10
        }

        return score
    }
}

@MainActor
final class WindowPositioner {
    private let panelController: OverlayPanelController
    private var timer: Timer?
    private var mouseMonitor: Any?
    private var workspaceObserver: Any?
    private var currentCursorPosition: CGPoint = .zero
    private var focusedWindowFrame: CGRect?
    private var focusedScreenNumber: UInt32?
    private var currentCorner: Corner?
    private var currentScreenNumber: UInt32?
    private var isPaused: Bool = false
    private var isTransitioning: Bool = false

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
        ) { [weak self] notif in
            let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                self?.handleAppActivation(app: app)
            }
        }

        // Check less frequently — corners don't need 12Hz
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.reposition()
        }

        if !AccessibilityHelper.hasPermission {
            AccessibilityHelper.requestPermission()
        }

        // Initial position
        reposition()
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

    private func screenNumber(for screen: NSScreen) -> UInt32? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }

    private func handleAppActivation(app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        focusedWindowFrame = AccessibilityHelper.focusedWindowFrame(for: app)

        if let frame = focusedWindowFrame {
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }) {
                focusedScreenNumber = screenNumber(for: screen)
            }
        } else {
            // Fallback: use cursor position to infer which screen the user is working on
            let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            if let mouseScreen {
                focusedScreenNumber = screenNumber(for: mouseScreen)
            }
        }

        // Reposition immediately on app switch
        reposition()
    }

    /// Determine which screen the user is currently working on, using cursor position.
    private func activeScreenNumber() -> UInt32? {
        let cursor = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) {
            return screenNumber(for: screen)
        }
        return nil
    }

    private func reposition() {
        guard !isPaused, !isTransitioning, panelController.isVisible else { return }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        // Use cursor position to determine which screen the user is on
        let userScreenNum = activeScreenNumber()

        // Pick target screen: prefer one the user isn't on
        let targetScreen: NSScreen
        if screens.count > 1, let usn = userScreenNum {
            targetScreen = screens.first(where: { screenNumber(for: $0) != usn }) ?? screens[0]
        } else {
            targetScreen = screens[0]
        }

        let targetScreenNum = screenNumber(for: targetScreen)
        let isOnUserScreen = targetScreenNum == userScreenNum

        let overlaySize = panelController.window.frame.size
        let result = PositionerLogic.bestCorner(
            screenBounds: targetScreen.visibleFrame,
            overlaySize: overlaySize,
            focusedWindowFrame: isOnUserScreen ? focusedWindowFrame : nil,
            cursorPosition: currentCursorPosition
        )

        // Only move if corner or screen changed
        if result.corner == currentCorner && targetScreenNum == currentScreenNumber {
            return
        }

        let targetFrame = NSRect(origin: result.origin, size: overlaySize)

        if currentCorner == nil {
            // First positioning — just place it
            panelController.setFrame(targetFrame, animate: false)
        } else {
            // Fade out, move, fade in
            isTransitioning = true
            panelController.fadeToFrame(targetFrame)
            // Allow next transition after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.isTransitioning = false
            }
        }

        currentCorner = result.corner
        currentScreenNumber = targetScreenNum
    }

}
