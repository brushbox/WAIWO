import AppKit
import ApplicationServices

enum AccessibilityHelper {
    // Use string literal to avoid Swift 6 concurrency issues with the global CFString
    private static let promptKey: String = "AXTrustedCheckOptionPrompt"

    static var hasPermission: Bool {
        AXIsProcessTrustedWithOptions(
            [promptKey: false] as CFDictionary
        )
    }

    static func requestPermission() {
        AXIsProcessTrustedWithOptions(
            [promptKey: true] as CFDictionary
        )
    }

    /// Returns the frame of the focused window of the given application, if accessible.
    static func focusedWindowFrame(for app: NSRunningApplication) -> NSRect? {
        guard hasPermission else { return nil }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let windowElement = focusedWindow else { return nil }

        var position: CFTypeRef?
        var size: CFTypeRef?
        AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXSizeAttribute as CFString, &size)

        guard let pos = position, let sz = size else { return nil }

        var point = CGPoint.zero
        var dimensions = CGSize.zero
        AXValueGetValue(pos as! AXValue, .cgPoint, &point)
        AXValueGetValue(sz as! AXValue, .cgSize, &dimensions)

        return NSRect(origin: point, size: dimensions)
    }
}
