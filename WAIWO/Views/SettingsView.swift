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

    private var onHotkeysChanged: () -> Void

    init(onHotkeysChanged: @escaping () -> Void) {
        self.onHotkeysChanged = onHotkeysChanged
        var kcs: [HotkeyAction: Int] = [:]
        var mods: [HotkeyAction: Int] = [:]
        for action in HotkeyAction.allCases {
            let setting = HotkeyConfig.read(for: action)
            kcs[action] = setting.keyCode
            mods[action] = setting.modifiers
        }
        _capturedKeyCodes = State(initialValue: kcs)
        _capturedModifiers = State(initialValue: mods)
    }

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                ForEach(HotkeyAction.allCases) { action in
                    hotkeyRow(action: action)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 320)
        .fixedSize()
        .alert("Invalid Shortcut", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
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