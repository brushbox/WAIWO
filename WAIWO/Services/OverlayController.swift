import AppKit
import Foundation

/// Facade over the overlay: feeds AppKit events into the layout reducer and
/// applies the resulting layouts to the panel. Callers see show/hide,
/// enterInput/exitInput and moveToNextScreen — ordering invariants live in
/// the reducer, not in the caller's head.
@MainActor
final class OverlayController {
    private let panelController: OverlayPanelController
    private var state = LayoutState()
    private var timer: Timer?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var workspaceObserver: Any?

    init(panelController: OverlayPanelController) {
        self.panelController = panelController
    }

    func start() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dispatch(.cursorMoved(NSEvent.mouseLocation))
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.dispatch(.cursorMoved(NSEvent.mouseLocation))
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
                self?.dispatch(.tick)
            }
        }

        if !AccessibilityHelper.hasPermission {
            AccessibilityHelper.requestPermission()
        }

        dispatch(.tick)
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

    func show() {
        dispatch(.animationStarted)
        panelController.show(targetOpacity: state.opacity) { [weak self] in
            self?.dispatch(.animationCompleted)
        }
    }

    func hide() {
        exitInput()
        panelController.hide()
    }

    func moveToNextScreen() {
        dispatch(.cycleScreen)
    }

    func enterInput(mode: InputView.Mode, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        guard !state.isInputMode else { return }
        let kind: OverlayLayoutComputer.InputKind = mode == .todo ? .todo : .journal
        panelController.presentInput(
            mode: mode,
            onSubmit: { [weak self] text in
                self?.exitInput()
                onSubmit(text)
            },
            onCancel: { [weak self] in
                self?.exitInput()
                onCancel()
            }
        )
        dispatch(.enterInput(kind))
    }

    func exitInput() {
        guard state.isInputMode else { return }
        panelController.dismissInputContent()
        dispatch(.exitInput)
    }

    private func handleAppActivation(app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        dispatch(.focusedWindowChanged(AccessibilityHelper.focusedWindowFrame(for: app)))
    }

    private func dispatch(_ event: LayoutEvent) {
        guard panelController.isVisible || isAlwaysDispatched(event) else {
            // Keep the focused-window fact current even while hidden, without
            // letting the reducer move a panel that isn't showing.
            if case .focusedWindowChanged(let frame) = event {
                state.focusedWindowFrame = frame
            }
            return
        }
        if let layout = OverlayLayoutComputer.reduce(&state, event: event, screens: currentScreens()) {
            panelController.apply(layout)
        }
    }

    private func isAlwaysDispatched(_ event: LayoutEvent) -> Bool {
        switch event {
        case .enterInput, .exitInput, .animationStarted, .animationCompleted:
            return true
        case .cursorMoved, .focusedWindowChanged, .tick, .cycleScreen:
            return false
        }
    }

    private func currentScreens() -> [ScreenInfo] {
        NSScreen.screens.map { screen in
            ScreenInfo(
                id: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32,
                visibleFrame: screen.visibleFrame
            )
        }
    }
}
