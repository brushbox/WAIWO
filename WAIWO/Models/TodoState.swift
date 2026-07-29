import Foundation
import Observation

enum DisplayState: Equatable {
    case activeTodo(text: String)
    case allDone
    case noNotesFound
}

@Observable
final class TodoState {
    var displayState: DisplayState = .noNotesFound
    var upcomingTodos: [String] = []  // 2nd and 3rd TODOs
    var currentLinks: [TodoLink] = []  // Links in the current TODO
    var isStale: Bool = false
    var noteDate: Date? = nil

    /// The single gate for scan results: applies every field so readers never
    /// observe a mix of old and new scan state.
    func apply(_ snapshot: NoteSnapshot) {
        displayState = snapshot.displayState
        upcomingTodos = snapshot.upcomingTodos
        currentLinks = snapshot.currentLinks
        isStale = snapshot.isStale
        noteDate = snapshot.noteDate
    }

    var staleDateText: String? {
        guard isStale, let noteDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "from \(formatter.string(from: noteDate))"
    }
}
