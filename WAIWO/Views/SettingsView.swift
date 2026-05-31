import SwiftUI
import Carbon
import AppKit

private func nsModifiersToCarbon(_ nsMods: Int) -> Int {
    var carbon: Int = 0
    if nsMods & Int(NSEvent.ModifierFlags.command.rawValue) != 0 { carbon |= Int(cmdKey) }
    if nsMods & Int(NSEvent.ModifierFlags.option.rawValue) != 0 { carbon |= Int(optionKey) }
    if nsMods & Int(NSEvent.ModifierFlags.shift.rawValue) != 0 { carbon |= Int(shiftKey) }
    if nsMods & Int(NSEvent.ModifierFlags.control.rawValue) != 0 { carbon |= Int(controlKey) }
    return carbon
}

struct SettingsView: View {
    @State private var recordings: [HotkeyAction: Bool] = [:]
    @State private var capturedKeyCodes: [HotkeyAction: Int] = [:]
    @State private var capturedModifiers: [HotkeyAction: Int] = [:]
    @State private var conflictMessages: [HotkeyAction: String] = [:]
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    @State private var dailyNotesPath: String
    @State private var journalPath: String

    private var onHotkeysChanged: () -> Void
    private var onPathsChanged: () -> Void

    init(onHotkeysChanged: @escaping () -> Void, onPathsChanged: @escaping () -> Void) {
        self.onHotkeysChanged = onHotkeysChanged
        self.onPathsChanged = onPathsChanged
        var kcs: [HotkeyAction: Int] = [:]
        var mods: [HotkeyAction: Int] = [:]
        for action in HotkeyAction.allCases {
            let setting = HotkeyConfig.read(for: action)
            kcs[action] = setting.keyCode
            mods[action] = setting.modifiers
        }
        _capturedKeyCodes = State(initialValue: kcs)
        _capturedModifiers = State(initialValue: mods)
        _dailyNotesPath = State(initialValue: PathConfig.readNotesPath())
        _journalPath = State(initialValue: PathConfig.readJournalPath())
    }

    var body: some View {
        Form {
            Section("Folders") {
                folderRow(
                    label: "Daily Notes",
                    path: $dailyNotesPath,
                    onChange: { PathConfig.writeNotesPath($0); onPathsChanged() }
                )
                folderRow(
                    label: "Daily Journal",
                    path: $journalPath,
                    onChange: { PathConfig.writeJournalPath($0); onPathsChanged() }
                )
            }

            Section("Keyboard Shortcuts") {
                ForEach(HotkeyAction.allCases) { action in
                    hotkeyRow(action: action)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 420)
        .fixedSize()
        .alert("Invalid Shortcut", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    @ViewBuilder
    private func folderRow(label: String, path: Binding<String>, onChange: @escaping (String) -> Void) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            TextField("", text: path)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 200)
                .onChange(of: path.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
            Button("Choose\u{2026}") {
                chooseFolder(current: path.wrappedValue) { selected in
                    if let selected {
                        path.wrappedValue = selected
                        onChange(selected)
                    }
                }
            }
        }
    }

    private func chooseFolder(current: String, completion: @escaping (String?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: current)
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(url.path)
            } else {
                completion(nil)
            }
        }
    }

    @ViewBuilder
    private func hotkeyRow(action: HotkeyAction) -> some View {
        let isRecording = recordings[action] ?? false
        let display = isRecording
            ? "Type shortcut\u{2026}"
            : HotkeyConfig.displayString(
                keyCode: capturedKeyCodes[action] ?? action.defaultKeyCode,
                modifiers: capturedModifiers[action] ?? action.defaultModifiers
            )

        HStack {
            Text(action.displayName)
                .foregroundStyle(.primary)
            Spacer()
            Button(display) {
                startRecording(action)
            }
            .buttonStyle(.bordered)
            .frame(minWidth: 140)
            .background(isRecording ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .background(
            KeyCaptureView(
                isRecording: isRecording,
                onCapture: { keyCode, mods in
                    finishRecording(action, keyCode: keyCode, modifiers: mods)
                }
            )
        )
    }

    private func startRecording(_ action: HotkeyAction) {
        for a in HotkeyAction.allCases {
            recordings[a] = false
        }
        recordings[action] = true
    }

    private func finishRecording(_ action: HotkeyAction, keyCode: Int, modifiers: Int) {
        recordings[action] = false

        let carbonMods = nsModifiersToCarbon(modifiers)
        guard carbonMods != 0 else {
            validationMessage = "Shortcuts must include at least one modifier key (⌘, ⌥, ⌃, or ⇧)."
            showValidationAlert = true
            return
        }

        for other in HotkeyAction.allCases where other != action {
            let otherKey = capturedKeyCodes[other] ?? other.defaultKeyCode
            let otherMods = capturedModifiers[other] ?? other.defaultModifiers
            if otherKey == keyCode && otherMods == carbonMods {
                conflictMessages[action] = "Already used by \"\(other.displayName)\""
                validationMessage = "\"\(HotkeyConfig.displayString(keyCode: keyCode, modifiers: carbonMods))\" is already assigned to \"\(other.displayName)\"."
                showValidationAlert = true
                return
            }
        }

        capturedKeyCodes[action] = keyCode
        capturedModifiers[action] = carbonMods
        conflictMessages[action] = nil

        UserDefaults.standard.set(keyCode, forKey: action.storageKeyCode)
        UserDefaults.standard.set(carbonMods, forKey: action.storageKeyModifiers)

        onHotkeysChanged()
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (Int, Int) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording {
            context.coordinator.startMonitoring(nsView)
        } else {
            context.coordinator.stopMonitoring()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject {
        let onCapture: (Int, Int) -> Void
        var monitor: Any?

        init(onCapture: @escaping (Int, Int) -> Void) {
            self.onCapture = onCapture
        }

        func startMonitoring(_ view: NSView) {
            stopMonitoring()
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }

                let keyCode = Int(event.keyCode)
                let mods = Int(event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue)

                self.onCapture(keyCode, mods)
                self.stopMonitoring()
                return nil
            }
        }

        func stopMonitoring() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        deinit {
            stopMonitoring()
        }
    }
}