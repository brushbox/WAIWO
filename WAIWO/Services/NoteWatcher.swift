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
        // Don't re-watch the same file
        if watchedNotePath == path { return }
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
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: directoryPath) else {
            print("NoteWatcher: failed to list directory contents")
            todoState.displayState = .noNotesFound
            todoState.isStale = false
            todoState.noteDate = nil
            return
        }

        let today = Date()
        guard let result = NoteFinder.bestNote(from: files, today: today) else {
            print("NoteWatcher: no matching note found")
            todoState.displayState = .noNotesFound
            todoState.isStale = false
            todoState.noteDate = nil
            return
        }

        let filePath = (directoryPath as NSString).appendingPathComponent(result.filename)

        // Watch this specific file for content changes
        startWatchingNote(at: filePath)

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("NoteWatcher: failed to read file content")
            todoState.displayState = .noNotesFound
            todoState.isStale = false
            todoState.noteDate = nil
            return
        }

        todoState.isStale = result.isStale
        todoState.noteDate = result.date

        let todos = NoteParser.uncheckedTodos(from: content, limit: 3)
        if let first = todos.first {
            let displayText = NoteParser.displayText(from: first)
            todoState.displayState = .activeTodo(text: displayText)
            todoState.currentLinks = NoteParser.extractLinks(from: first)
            todoState.upcomingTodos = Array(todos.dropFirst()).map { NoteParser.displayText(from: $0) }
            print("NoteWatcher: found todo: \(displayText), upcoming: \(todoState.upcomingTodos.count), links: \(todoState.currentLinks.count)")
        } else {
            print("NoteWatcher: all done")
            todoState.displayState = .allDone
            todoState.upcomingTodos = []
            todoState.currentLinks = []
        }
    }

    deinit {
        stop()
    }
}
