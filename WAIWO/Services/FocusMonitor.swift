import Foundation

final class FocusMonitor {
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var debounceWorkItem: DispatchWorkItem?
    private var lastKnownState: Bool = false
    var onFocusModeChanged: ((Bool) -> Void)?

    private let assertionsPath: String = {
        (NSHomeDirectory() as NSString).appendingPathComponent(
            "Library/DoNotDisturb/DB/Assertions.json"
        )
    }()

    func start() {
        // Check initial state
        let initial = isFocusModeActive()
        lastKnownState = initial
        onFocusModeChanged?(initial)

        // Watch the assertions file for changes
        startWatchingFile()

        // Poll as fallback every 5 seconds in case file watching misses events
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkState()
        }
    }

    func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func startWatchingFile() {
        let fd = open(assertionsPath, O_EVTONLY)
        guard fd != -1 else {
            print("FocusMonitor: failed to open assertions file for monitoring")
            return
        }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleCheck()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        dispatchSource = source
    }

    private func scheduleCheck() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkState()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func checkState() {
        let active = isFocusModeActive()
        if active != lastKnownState {
            lastKnownState = active
            print("FocusMonitor: Focus mode \(active ? "activated" : "deactivated")")
            onFocusModeChanged?(active)
        }
    }

    /// Checks if any Focus mode is currently active by reading the assertions database.
    private func isFocusModeActive() -> Bool {
        guard let data = FileManager.default.contents(atPath: assertionsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            return false
        }

        for entry in entries {
            if let records = entry["storeAssertionRecords"] as? [[String: Any]], !records.isEmpty {
                return true
            }
        }
        return false
    }

    deinit {
        stop()
    }
}
