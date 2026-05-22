import Carbon
import AppKit

final class HotkeyManager: @unchecked Sendable {
    nonisolated(unsafe) static let shared = HotkeyManager()

    // Key codes
    static let keyT: UInt32 = UInt32(kVK_ANSI_T)
    static let keyN: UInt32 = UInt32(kVK_ANSI_N)
    static let keyJ: UInt32 = UInt32(kVK_ANSI_J)
    static let keyD: UInt32 = UInt32(kVK_ANSI_D)

    // Modifier masks
    static let modOption: UInt32 = UInt32(optionKey)
    static let modCmd: UInt32 = UInt32(cmdKey)
    static let modShift: UInt32 = UInt32(shiftKey)

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerInstalled = false

    private let signature: OSType = 0x5741_4957

    private init() {}

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) -> UInt32 {
        let id = nextID
        nextID += 1

        ensureEventHandler()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = signature
        hotKeyID.id = id

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr, let ref = hotKeyRef else {
            print("HotkeyManager: failed to register hotkey (error \(status))")
            return id
        }

        hotKeyRefs[id] = ref
        handlers[id] = onPress
        return id
    }

    func unregister(id: UInt32) {
        guard let ref = hotKeyRefs[id] else { return }
        UnregisterEventHotKey(ref)
        hotKeyRefs.removeValue(forKey: id)
        handlers.removeValue(forKey: id)
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }

    private func ensureEventHandler() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr else { return err }

            if let handler = HotkeyManager.shared.handlers[hotKeyID.id] {
                handler()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}