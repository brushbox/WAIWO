import Foundation
import Observation

@Observable
final class NoteWatcher {
    private let directoryPath: String
    private let todoState: TodoState
    private var dirFileDescriptor: Int32 = -1
    private var noteFileDescriptor: Int32 = -1
    private var dirSource: DispatchSourceFileSystemObject?
    private var noteSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private var watchedNotePath: String?
    private var lastFailureReason: String?
    private(set) var lastScanTime: Date?

    init(directoryPath: String, todoState: TodoState) {
        self.directoryPath = directoryPath
        self.todoState = todoState
    }

    func start() {
        scan()
        startWatchingDirectory()
    }

    func stop() {
        stopWatchingNote()
        dirSource?.cancel()
        dirSource = nil
        if dirFileDescriptor != -1 {
            close(dirFileDescriptor)
            dirFileDescriptor = -1
        }
    }

    private func startWatchingDirectory() {
        let fd = open(directoryPath, O_EVTONLY)
        guard fd != -1 else {
            print("NoteWatcher: failed to open directory for monitoring")
            return
        }
        dirFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        dirSource = source
    }

    private func startWatchingNote(at path: String) {
        stopWatchingNote()

        let fd = open(path, O_EVTONLY)
        guard fd != -1 else {
            print("NoteWatcher: failed to open note file for monitoring: \(path)")
            return
        }
        noteFileDescriptor = fd
        watchedNotePath = path

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            print("NoteWatcher: note file changed, re-scanning")
            self?.scheduleScan()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        noteSource = source
    }

    private func stopWatchingNote() {
        noteSource?.cancel()
        noteSource = nil
        noteFileDescriptor = -1
        watchedNotePath = nil
    }

    private func scheduleScan() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.scan()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func scan() {
        lastScanTime = Date()

        let snapshot = NoteScanner.scan(directory: directoryPath)
        lastFailureReason = snapshot.failureReason
        if let reason = snapshot.failureReason {
            print("NoteWatcher: \(reason)")
        }
        todoState.apply(snapshot)
        retargetNoteWatcher(to: snapshot.notePath)
    }

    private func retargetNoteWatcher(to path: String?) {
        guard path != watchedNotePath else { return }
        if let path {
            startWatchingNote(at: path)
        } else {
            stopWatchingNote()
        }
    }

    var debugInfo: String {
        var lines: [String] = []
        lines.append("Directory: \(directoryPath)")
        if let path = watchedNotePath {
            lines.append("Watched file: \(path)")
        } else {
            lines.append("Watched file: (none)")
        }
        lines.append("Directory watcher: \(dirSource != nil ? "active" : "inactive")")
        lines.append("Note watcher: \(noteSource != nil ? "active" : "inactive")")
        if let lastScan = lastScanTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            lines.append("Last scan: \(formatter.string(from: lastScan))")
        } else {
            lines.append("Last scan: (never)")
        }
        if let reason = lastFailureReason {
            lines.append("Last scan failure: \(reason)")
        }
        return lines.joined(separator: "\n")
    }

    deinit {
        stop()
    }
}
