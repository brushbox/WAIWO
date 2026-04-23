import Foundation
import Observation

@Observable
final class NoteWatcher {
    private let directoryPath: String
    private let todoState: TodoState
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?

    init(directoryPath: String, todoState: TodoState) {
        self.directoryPath = directoryPath
        self.todoState = todoState
    }

    func start() {
        scan()
        startWatching()
    }

    func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func startWatching() {
        let fd = open(directoryPath, O_EVTONLY)
        guard fd != -1 else {
            print("NoteWatcher: failed to open directory for monitoring")
            return
        }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        source.resume()
        dispatchSource = source
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
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: directoryPath) else {
            todoState.displayState = .noNotesFound
            todoState.isStale = false
            todoState.noteDate = nil
            return
        }

        let today = Date()
        guard let result = NoteFinder.bestNote(from: files, today: today) else {
            todoState.displayState = .noNotesFound
            todoState.isStale = false
            todoState.noteDate = nil
            return
        }

        let filePath = (directoryPath as NSString).appendingPathComponent(result.filename)
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            todoState.displayState = .noNotesFound
            todoState.isStale = false
            todoState.noteDate = nil
            return
        }

        todoState.isStale = result.isStale
        todoState.noteDate = result.date

        if let todo = NoteParser.firstUncheckedTodo(from: content) {
            todoState.displayState = .activeTodo(text: todo)
        } else {
            todoState.displayState = .allDone
        }
    }

    deinit {
        stop()
    }
}
