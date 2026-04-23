import Carbon
import AppKit

final class HotkeyManager: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var onToggle: (() -> Void)?

    nonisolated(unsafe) static let shared = HotkeyManager()

    private init() {}

    func register(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5741_4957) // "WAIW"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            HotkeyManager.shared.onToggle?()
            return noErr
        }, 1, &eventType, nil, nil)

        let modifiers = UInt32(optionKey | cmdKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        unregister()
    }
}
