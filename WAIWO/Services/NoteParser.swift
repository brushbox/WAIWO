import Foundation

enum NoteParser {
    /// Finds the first unchecked markdown TODO (`- [ ] text`) in the given content.
    static func firstUncheckedTodo(from content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ] ") {
                let todo = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                return todo.isEmpty ? nil : todo
            }
        }
        return nil
    }
}
