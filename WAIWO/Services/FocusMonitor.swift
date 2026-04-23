import Foundation

final class FocusMonitor {
    private var observer: Any?
    private var dndObserver: Any?
    var onFocusModeChanged: ((Bool) -> Void)?

    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api.focusModeStatus"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isActive = notification.userInfo?["enabled"] as? Bool ?? false
            self?.onFocusModeChanged?(isActive)
        }

        dndObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let dndEnabled = self?.isDNDEnabled() ?? false
            self?.onFocusModeChanged?(dndEnabled)
        }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let dndObserver {
            DistributedNotificationCenter.default().removeObserver(dndObserver)
        }
        observer = nil
        dndObserver = nil
    }

    private func isDNDEnabled() -> Bool {
        let defaults = UserDefaults(suiteName: "com.apple.controlcenter")
        return defaults?.bool(forKey: "NSStatusItem Visible FocusModes") ?? false
    }

    deinit {
        stop()
    }
}
