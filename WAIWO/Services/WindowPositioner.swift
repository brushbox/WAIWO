import AppKit
import Foundation

@MainActor
final class WindowPositioner {
    private let panelController: OverlayPanelController
    private var timer: Timer?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var workspaceObserver: Any?
    private var currentCursorPosition: CGPoint = .zero
    private var focusedWindowFrame: CGRect?
    private var currentPosition: CGPoint?
    private var currentScreenNumber: UInt32?
    private var isPaused: Bool = false
    private var isTransitioning: Bool = false
    private var isMouseOverWindow = false

    init(panelController: OverlayPanelController) {
        self.panelController = panelController
    }

    func start() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleGlobalMouseMoved()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleLocalMouseMoved()
            return event
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

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reposition()
            }
        }

        if !AccessibilityHelper.hasPermission {
            AccessibilityHelper.requestPermission()
        }

        reposition()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    func moveToNextScreen() {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }
        let currentIdx = screens.firstIndex(where: { screenNumber(for: $0) == currentScreenNumber }) ?? 0
        let nextIdx = (currentIdx + 1) % screens.count
        let next = screens[nextIdx]
        currentScreenNumber = screenNumber(for: next)
        currentPosition = nil
        reposition()
    }

    func updateProximityOpacity() {
        guard !isPaused, !panelController.isInputModeActive, panelController.isVisible else { return }
        if isMouseOverWindow {
            panelController.setProximityOpacity(0, animated: true)
        } else {
            let opacity = calculatedOpacity(cursorPosition: currentCursorPosition)
            panelController.setProximityOpacity(opacity, animated: true)
        }
    }

    private func screenNumber(for screen: NSScreen) -> UInt32? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }

    private func handleAppActivation(app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        focusedWindowFrame = AccessibilityHelper.focusedWindowFrame(for: app)

        reposition()
    }

    private func handleGlobalMouseMoved() {
        currentCursorPosition = NSEvent.mouseLocation

        guard panelController.isVisible, !isPaused, !panelController.isInputModeActive else { return }

        let panelFrame = panelController.window.frame
        let isOver = panelFrame.contains(currentCursorPosition)

        if isMouseOverWindow {
            if !isOver {
                isMouseOverWindow = false
                let opacity = calculatedOpacity(cursorPosition: currentCursorPosition)
                panelController.setProximityOpacity(opacity, animated: true)
            }
            return
        }

        if isOver {
            isMouseOverWindow = true
            panelController.setProximityOpacity(0, animated: true)
            return
        }

        let opacity = calculatedOpacity(cursorPosition: currentCursorPosition)
        panelController.setProximityOpacity(opacity, animated: true)
    }

    private func handleLocalMouseMoved() {
        guard panelController.isVisible, !isPaused, !panelController.isInputModeActive else { return }

        let cursorPos = NSEvent.mouseLocation
        let panelFrame = panelController.window.frame
        let isOver = panelFrame.contains(cursorPos)

        if isOver && !isMouseOverWindow {
            isMouseOverWindow = true
            panelController.setProximityOpacity(0, animated: true)
        } else if !isOver && isMouseOverWindow {
            isMouseOverWindow = false
            let opacity = calculatedOpacity(cursorPosition: cursorPos)
            panelController.setProximityOpacity(opacity, animated: true)
        }
    }

    private func calculatedOpacity(cursorPosition: CGPoint) -> CGFloat {
        let frame = panelController.window.frame
        let distance = distanceToRect(cursorPosition, frame)

        let minOpacity: CGFloat = 0.05
        let effectRadius = OverlayLayoutComputer.cursorAvoidanceRadius

        if distance <= 0 { return minOpacity }
        if distance >= effectRadius { return 1.0 }

        let t = distance / effectRadius
        return minOpacity + (1.0 - minOpacity) * t
    }

    private func distanceToRect(_ point: CGPoint, _ rect: NSRect) -> CGFloat {
        let closestX = max(rect.minX, min(point.x, rect.maxX))
        let closestY = max(rect.minY, min(point.y, rect.maxY))
        let dx = point.x - closestX
        let dy = point.y - closestY
        return hypot(dx, dy)
    }

    private func reposition() {
        guard !isPaused, !isTransitioning, panelController.isVisible else { return }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let targetScreen: NSScreen
        if let current = currentScreenNumber, let screen = screens.first(where: { screenNumber(for: $0) == current }) {
            targetScreen = screen
        } else {
            targetScreen = screens.first ?? screens[0]
            currentScreenNumber = screenNumber(for: targetScreen)
        }

        let overlaySize = panelController.window.frame.size
        let result = OverlayLayoutComputer.bestPosition(
            screenBounds: targetScreen.visibleFrame,
            overlaySize: overlaySize,
            currentPosition: currentPosition,
            focusedWindowFrame: focusedWindowFrame,
            cursorPosition: currentCursorPosition
        )

        if result == currentPosition {
            return
        }

        let targetFrame = NSRect(origin: result, size: overlaySize)

        if currentPosition == nil {
            panelController.setFrame(targetFrame, animate: false)
        } else {
            isTransitioning = true
            panelController.fadeToFrame(targetFrame)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.isTransitioning = false
            }
        }

        currentPosition = result

        updateProximityOpacity()
    }
}