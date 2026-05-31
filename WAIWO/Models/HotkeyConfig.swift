import Carbon
import AppKit

enum HotkeyAction: String, CaseIterable, Identifiable {
    case toggleOverlay
    case newTodo
    case newJournal
    case markDone
    case cycleDisplay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggleOverlay: "Toggle Overlay"
        case .newTodo: "Add TODO"
        case .newJournal: "Add Journal Entry"
        case .markDone: "Mark Top TODO as Done"
        case .cycleDisplay: "Move to Next Display"
        }
    }

    var defaultKeyCode: Int {
        switch self {
        case .toggleOverlay: Int(kVK_ANSI_T)
        case .newTodo: Int(kVK_ANSI_N)
        case .newJournal: Int(kVK_ANSI_J)
        case .markDone: Int(kVK_ANSI_D)
        case .cycleDisplay: Int(kVK_ANSI_Y)
        }
    }

    var defaultModifiers: Int {
        switch self {
        case .toggleOverlay: Int(optionKey) | Int(cmdKey)
        case .newTodo: Int(optionKey) | Int(cmdKey)
        case .newJournal: Int(optionKey) | Int(cmdKey) | Int(shiftKey)
        case .markDone: Int(optionKey) | Int(cmdKey)
        case .cycleDisplay: Int(optionKey) | Int(cmdKey) | Int(shiftKey)
        }
    }

    static let storageKeyCodePrefix = "hotkey_keyCode_"
    static let storageKeyModifiersPrefix = "hotkey_modifiers_"

    var storageKeyCode: String { Self.storageKeyCodePrefix + rawValue }
    var storageKeyModifiers: String { Self.storageKeyModifiersPrefix + rawValue }
}

struct HotkeySetting: Equatable {
    var keyCode: Int
    var modifiers: Int
}

enum HotkeyConfig {
    static func registerDefaults() {
        var defaults: [String: Any] = [:]
        for action in HotkeyAction.allCases {
            defaults[action.storageKeyCode] = action.defaultKeyCode
            defaults[action.storageKeyModifiers] = action.defaultModifiers
        }
        UserDefaults.standard.register(defaults: defaults)
    }

    static func read(for action: HotkeyAction) -> HotkeySetting {
        let ud = UserDefaults.standard
        return HotkeySetting(
            keyCode: ud.integer(forKey: action.storageKeyCode),
            modifiers: ud.integer(forKey: action.storageKeyModifiers)
        )
    }

    static func readRaw(for action: HotkeyAction) -> (keyCode: UInt32, modifiers: UInt32) {
        let s = read(for: action)
        return (UInt32(s.keyCode), UInt32(s.modifiers))
    }

    static func allCurrent() -> [HotkeyAction: HotkeySetting] {
        var result: [HotkeyAction: HotkeySetting] = [:]
        for action in HotkeyAction.allCases {
            result[action] = read(for: action)
        }
        return result
    }
}

extension HotkeyConfig {
    static func displayString(keyCode: Int, modifiers: Int) -> String {
        var parts: [String] = []
        if modifiers & Int(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & Int(optionKey) != 0 { parts.append("⌥") }
        if modifiers & Int(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & Int(controlKey) != 0 { parts.append("⌃") }

        if let char = keyCodeToDisplayCharacter(keyCode) {
            parts.append(char)
        } else {
            parts.append("?")
        }
        return parts.joined()
    }

    private static func keyCodeToDisplayCharacter(_ keyCode: Int) -> String? {
        let uck = UInt16(keyCode)
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else {
            return fallbackDisplayName(Int16(keyCode))
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        let ptr = data.withUnsafeBytes { $0.bindMemory(to: UCKeyboardLayout.self).baseAddress! }

        var deadKey: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let err = UCKeyTranslate(
            ptr,
            uck,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKey,
            4,
            &length,
            &chars
        )
        if err == noErr {
            return String(utf16CodeUnits: chars, count: length).localizedUppercase
        }
        return fallbackDisplayName(Int16(keyCode))
    }

    private static func fallbackDisplayName(_ keyCode: Int16) -> String? {
        let map: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C",
            kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
            kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I",
            kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
            kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
            kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U",
            kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2",
            kVK_ANSI_3: "3", kVK_ANSI_4: "4", kVK_ANSI_5: "5",
            kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8",
            kVK_ANSI_9: "9",
            kVK_ANSI_Comma: ",", kVK_ANSI_Slash: "/",
            kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
            kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Backslash: "\\", kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
            kVK_ANSI_Grave: "`",
            kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
            kVK_Delete: "⌫", kVK_Escape: "Esc",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3",
            kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9",
            kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        return map[Int(keyCode)]
    }
}