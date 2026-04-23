import Foundation

struct TodoLink: Equatable {
    let text: String
    let url: URL
}

enum NoteParser {
    /// Finds the first unchecked markdown TODO (`- [ ] text`) in the given content.
    static func firstUncheckedTodo(from content: String) -> String? {
        uncheckedTodos(from: content, limit: 1).first
    }

    /// Returns up to `limit` unchecked markdown TODOs from the given content.
    static func uncheckedTodos(from content: String, limit: Int = 3) -> [String] {
        var results: [String] = []
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ] ") {
                let todo = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                if !todo.isEmpty {
                    results.append(todo)
                    if results.count >= limit { break }
                }
            }
        }
        return results
    }

    /// Extracts markdown links `[text](url)` from a string.
    static func extractLinks(from text: String) -> [TodoLink] {
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let textRange = Range(match.range(at: 1), in: text),
                  let urlRange = Range(match.range(at: 2), in: text),
                  let url = URL(string: String(text[urlRange])) else { return nil }
            return TodoLink(text: String(text[textRange]), url: url)
        }
    }

    /// Returns display text with markdown links replaced by just their link text.
    static func displayText(from text: String) -> String {
        let pattern = #"\[([^\]]+)\]\([^)]+\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var result = text
        // Replace in reverse order to preserve ranges
        for match in regex.matches(in: text, range: range).reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let textRange = Range(match.range(at: 1), in: result) else { continue }
            let linkText = String(result[textRange])
            result.replaceSubrange(fullRange, with: linkText)
        }
        return result
    }
}
