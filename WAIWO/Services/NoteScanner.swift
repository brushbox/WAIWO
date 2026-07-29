import Foundation

/// Everything the overlay should show as a result of reading the daily notes
/// directory, produced in one shot so it can be applied atomically.
struct NoteSnapshot: Equatable {
    var displayState: DisplayState
    var upcomingTodos: [String] = []
    var currentLinks: [TodoLink] = []
    var isStale: Bool = false
    var noteDate: Date? = nil
    /// Path of the chosen Latest Daily Note, populated whenever a note was
    /// chosen — even if reading it failed — so the watcher can keep watching it.
    var notePath: String? = nil
    var failureReason: String? = nil
}

/// The reading pipeline: list the directory, pick the Latest Daily Note,
/// read it, parse TODOs. Total function — failures are `.noNotesFound`
/// snapshots, never thrown.
enum NoteScanner {
    static func scan(directory: String, today: Date = Date()) -> NoteSnapshot {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return NoteSnapshot(
                displayState: .noNotesFound,
                failureReason: "failed to list directory contents"
            )
        }

        guard let result = NoteFinder.bestNote(from: files, today: today) else {
            return NoteSnapshot(
                displayState: .noNotesFound,
                failureReason: "no matching note found"
            )
        }

        let notePath = (directory as NSString).appendingPathComponent(result.filename)

        guard let content = try? String(contentsOfFile: notePath, encoding: .utf8) else {
            return NoteSnapshot(
                displayState: .noNotesFound,
                notePath: notePath,
                failureReason: "failed to read \(result.filename)"
            )
        }

        let todos = NoteParser.uncheckedTodos(from: content, limit: 3)
        guard let first = todos.first else {
            return NoteSnapshot(
                displayState: .allDone,
                isStale: result.isStale,
                noteDate: result.date,
                notePath: notePath
            )
        }

        return NoteSnapshot(
            displayState: .activeTodo(text: NoteParser.displayText(from: first)),
            upcomingTodos: Array(todos.dropFirst()).map { NoteParser.displayText(from: $0) },
            currentLinks: NoteParser.extractLinks(from: first),
            isStale: result.isStale,
            noteDate: result.date,
            notePath: notePath
        )
    }
}
