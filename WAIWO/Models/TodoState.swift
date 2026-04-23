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

    var staleDateText: String? {
        guard isStale, let noteDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "from \(formatter.string(from: noteDate))"
    }
}
