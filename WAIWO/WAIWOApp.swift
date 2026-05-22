import Observation
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class AppServices {
    static let shared = AppServices()

    let todoState = TodoState()
    var panelController: OverlayPanelController?
    var windowPositioner: WindowPositioner?
    var noteWatcher: NoteWatcher?
    var focusMonitor: FocusMonitor?
    var wasVisibleBeforeFocus = true
    var isVisible = true

    private let dailyNotesPath = (NSHomeDirectory() as NSString).appendingPathComponent(
        "Library/Mobile Documents/iCloud~md~obsidian/Documents/Pete/Areas/Daily Notes"
    )
    private let journalPath = (NSHomeDirectory() as NSString).appendingPathComponent(
        "Library/Mobile Documents/iCloud~md~obsidian/Documents/Pete/Areas/Daily Journal"
    )

    private var toggleHotkeyID: UInt32 = 0
    private var todoHotkeyID: UInt32 = 0
    private var journalHotkeyID: UInt32 = 0

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

        let focus = FocusMonitor.shared
        focus.onFocusModeChanged = { [weak self] isActive in
            guard let self else { return }
            if isActive {
                self.wasVisibleBeforeFocus = self.isVisible
                if self.isVisible { self.hideOverlay() }
            } else {
                if self.wasVisibleBeforeFocus { self.showOverlay() }
            }
        }
        focusMonitor = focus

        registerHotkeys(controller: controller)

        startObservingTodoState()
        controller.show()
        controller.updateContent()
    }

    private func registerHotkeys(controller: OverlayPanelController) {
        let hotkey = HotkeyManager.shared

        toggleHotkeyID = hotkey.register(keyCode: HotkeyManager.keyT, modifiers: HotkeyManager.modOption | HotkeyManager.modCmd) { [weak self] in
            self?.toggleVisibility()
        }

        todoHotkeyID = hotkey.register(keyCode: HotkeyManager.keyN, modifiers: HotkeyManager.modOption | HotkeyManager.modCmd) { [weak self] in
            self?.presentInput(mode: .todo)
        }

        journalHotkeyID = hotkey.register(keyCode: HotkeyManager.keyJ, modifiers: HotkeyManager.modOption | HotkeyManager.modCmd | HotkeyManager.modShift) { [weak self] in
            self?.presentInput(mode: .journal)
        }
    }

    private func presentInput(mode: InputView.Mode) {
        guard let controller = panelController else { return }

        if !isVisible {
            controller.show()
            isVisible = true
        }

        windowPositioner?.pause()

        controller.showInput(
            mode: mode,
            onSubmit: { [weak self] text in
                guard let self else { return }
                self.handleInputSubmit(text: text, mode: mode)
            },
            onCancel: { [weak self] in
                self?.windowPositioner?.resume()
            }
        )
    }

    private func handleInputSubmit(text: String, mode: InputView.Mode) {
        defer { windowPositioner?.resume() }

        switch mode {
        case .todo:
            let result = NoteWriter.write(todo: text, to: dailyNotesPath)
            if case .failure(let error) = result {
                print("AppServices: failed to write todo: \(error)")
            }
        case .journal:
            let result = JournalWriter.write(entry: text, to: journalPath)
            if case .failure(let error) = result {
                print("AppServices: failed to write journal entry: \(error)")
            }
        }
    }

    private func startObservingTodoState() {
        withObservationTracking {
            _ = todoState.displayState
            _ = todoState.isStale
            _ = todoState.upcomingTodos
            _ = todoState.currentLinks
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.panelController?.updateContent()
                self?.startObservingTodoState()
            }
        }
    }

    func toggleVisibility() {
        guard let controller = panelController else { return }
        if controller.window.isVisible && controller.window.isKeyWindow && controller.window.canBecomeKey {
            controller.dismissInput()
        }
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
        HotkeyManager.shared.unregisterAll()
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
                let display = text.count > 40 ? String(text.prefix(40)) + "\u{2026}" : text
                Text("Showing: \(display)")
                    .foregroundStyle(.secondary)
            case .allDone:
                Text("All done!")
                    .foregroundStyle(.secondary)
            case .noNotesFound:
                Text("No daily notes found")
                    .foregroundStyle(.secondary)
            }

            if !todoState.currentLinks.isEmpty {
                Divider()
                ForEach(todoState.currentLinks, id: \.url) { link in
                    Button {
                        NSWorkspace.shared.open(link.url)
                    } label: {
                        let host = link.url.host ?? link.url.absoluteString
                        Text("\(link.text) \u{2014} \(host)")
                    }
                }
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