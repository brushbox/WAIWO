import Observation
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class AppServices {
    static let shared = AppServices()

    let todoState = TodoState()
    var panelController: OverlayPanelController?
    var overlayController: OverlayController?
    var noteWatcher: NoteWatcher?
    var focusMonitor: FocusMonitor?
    var wasVisibleBeforeFocus = true
    var isVisible = true

    var dailyNotesPath: String { PathConfig.readNotesPath() }
    var journalPath: String { PathConfig.readJournalPath() }

    private var toggleHotkeyID: UInt32 = 0
    private var todoHotkeyID: UInt32 = 0
    private var journalHotkeyID: UInt32 = 0
    private var markDoneHotkeyID: UInt32 = 0
    private var cycleDisplayHotkeyID: UInt32 = 0

    private init() {
        HotkeyConfig.registerDefaults()
        PathConfig.registerDefaults()
    }

    func setup() {
        let controller = OverlayPanelController(todoState: todoState)
        panelController = controller

        let watcher = NoteWatcher(directoryPath: dailyNotesPath, todoState: todoState)
        watcher.start()
        noteWatcher = watcher

        let overlay = OverlayController(panelController: controller)
        overlayController = overlay

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
        overlay.show()
        overlay.start()
        controller.updateContent()
    }

    private func registerHotkeys(controller: OverlayPanelController) {
        let hotkey = HotkeyManager.shared

        let toggleSetting = HotkeyConfig.readRaw(for: .toggleOverlay)
        toggleHotkeyID = hotkey.register(keyCode: toggleSetting.keyCode, modifiers: toggleSetting.modifiers) { [weak self] in
            self?.toggleVisibility()
        }

        let todoSetting = HotkeyConfig.readRaw(for: .newTodo)
        todoHotkeyID = hotkey.register(keyCode: todoSetting.keyCode, modifiers: todoSetting.modifiers) { [weak self] in
            self?.presentInput(mode: .todo)
        }

        let journalSetting = HotkeyConfig.readRaw(for: .newJournal)
        journalHotkeyID = hotkey.register(keyCode: journalSetting.keyCode, modifiers: journalSetting.modifiers) { [weak self] in
            self?.presentInput(mode: .journal)
        }

        let markDoneSetting = HotkeyConfig.readRaw(for: .markDone)
        markDoneHotkeyID = hotkey.register(keyCode: markDoneSetting.keyCode, modifiers: markDoneSetting.modifiers) { [weak self] in
            self?.markTopTodoDone()
        }

        let cycleSetting = HotkeyConfig.readRaw(for: .cycleDisplay)
        cycleDisplayHotkeyID = hotkey.register(keyCode: cycleSetting.keyCode, modifiers: cycleSetting.modifiers) { [weak self] in
            self?.overlayController?.moveToNextScreen()
        }
    }

    func reapplyHotkeys() {
        guard let controller = panelController else { return }
        HotkeyManager.shared.unregisterAll()
        registerHotkeys(controller: controller)
    }

    func pathsDidChange() {
        noteWatcher?.stop()
        let watcher = NoteWatcher(directoryPath: dailyNotesPath, todoState: todoState)
        watcher.start()
        noteWatcher = watcher
    }

    func presentInput(mode: InputView.Mode) {
        guard let overlay = overlayController else { return }

        if !isVisible {
            showOverlay()
        }

        overlay.enterInput(
            mode: mode,
            onSubmit: { [weak self] text in
                guard let self else { return }
                self.handleInputSubmit(text: text, mode: mode)
            },
            onCancel: {}
        )
    }

    private func handleInputSubmit(text: String, mode: InputView.Mode) {
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
        overlayController?.exitInput()
        if isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func showOverlay() {
        overlayController?.show()
        isVisible = true
    }

    func hideOverlay() {
        overlayController?.hide()
        isVisible = false
    }

    func markTopTodoDone() {
        let result = NoteWriter.markTopTodoDone(to: dailyNotesPath)
        if case .failure(let error) = result {
            print("AppServices: failed to mark todo done: \(error)")
        }
    }

    func cleanup() {
        noteWatcher?.stop()
        overlayController?.stop()
        focusMonitor?.stop()
        HotkeyManager.shared.unregisterAll()
    }

    func showDebugInfo() {
        guard let watcher = noteWatcher else { return }
        let info = watcher.debugInfo

        let alert = NSAlert()
        alert.messageText = "WAIWO Debug Info"
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

            Button("Add TODO\u{2026}") {
                services.presentInput(mode: .todo)
            }

            Button("Add Journal Entry\u{2026}") {
                services.presentInput(mode: .journal)
            }

            Button("Mark Top TODO as Done") {
                services.markTopTodoDone()
            }

            Button("Move to Next Display") {
                services.overlayController?.moveToNextScreen()
            }

            Divider()

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

            SettingsLink {
                Text("Settings\u{2026}")
            }
            .keyboardShortcut(",")

            Button("Show Debug Info") {
                services.showDebugInfo()
            }

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

        Settings {
            SettingsView(onHotkeysChanged: {
                AppServices.shared.reapplyHotkeys()
            }, onPathsChanged: {
                AppServices.shared.pathsDidChange()
            })
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