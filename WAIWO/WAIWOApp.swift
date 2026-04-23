import SwiftUI
import ServiceManagement

@MainActor
final class AppServices {
    static let shared = AppServices()

    let todoState = TodoState()
    var panelController: OverlayPanelController?
    var windowPositioner: WindowPositioner?
    var noteWatcher: NoteWatcher?
    var focusMonitor: FocusMonitor?
    var wasVisibleBeforeFocus = true
    var isVisible = true

    private let dailyNotesPath = (
        NSHomeDirectory() as NSString
    ).appendingPathComponent(
        "Library/Mobile Documents/iCloud~md~obsidian/Documents/Pete/Areas/Daily Notes"
    )

    private init() {}

    func setup() {
        let controller = OverlayPanelController(todoState: todoState)
        panelController = controller

        let watcher = NoteWatcher(directoryPath: dailyNotesPath, todoState: todoState)
        watcher.start()
        noteWatcher = watcher

        let positioner = WindowPositioner(panelController: controller)
        positioner.start()
        windowPositioner = positioner

        let focus = FocusMonitor()
        focus.onFocusModeChanged = { [weak self] isActive in
            guard let self else { return }
            if isActive {
                self.wasVisibleBeforeFocus = self.isVisible
                if self.isVisible { self.hideOverlay() }
            } else {
                if self.wasVisibleBeforeFocus { self.showOverlay() }
            }
        }
        focus.start()
        focusMonitor = focus

        HotkeyManager.shared.register { [weak self] in
            self?.toggleVisibility()
        }

        controller.show()
    }

    func toggleVisibility() {
        if isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func showOverlay() {
        panelController?.show()
        windowPositioner?.resume()
        isVisible = true
    }

    func hideOverlay() {
        panelController?.hide()
        windowPositioner?.pause()
        isVisible = false
    }

    func cleanup() {
        noteWatcher?.stop()
        windowPositioner?.stop()
        focusMonitor?.stop()
        HotkeyManager.shared.unregister()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppServices.shared.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppServices.shared.cleanup()
    }
}

@main
struct WAIWOApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launchAtLogin = false

    private var services: AppServices { AppServices.shared }
    private var todoState: TodoState { AppServices.shared.todoState }

    var body: some Scene {
        MenuBarExtra("WAIWO", systemImage: "checklist") {
            Button(services.isVisible ? "Hide Overlay" : "Show Overlay") {
                services.toggleVisibility()
            }
            .keyboardShortcut("t", modifiers: [.option, .command])

            switch todoState.displayState {
            case .activeTodo(let text):
                let display = text.count > 40 ? String(text.prefix(40)) + "…" : text
                Text("Showing: \(display)")
                    .foregroundStyle(.secondary)
            case .allDone:
                Text("All done!")
                    .foregroundStyle(.secondary)
            case .noNotesFound:
                Text("No daily notes found")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Start at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

            Button("Quit") {
                services.cleanup()
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: todoState.displayState) { _, _ in
            services.panelController?.updateContent()
        }
        .onChange(of: todoState.isStale) { _, _ in
            services.panelController?.updateContent()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}
