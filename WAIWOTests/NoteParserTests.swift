import Testing
import Foundation
@testable import WAIWO

struct NoteParserTests {
    @Test func extractsFirstUncheckedTodo() {
        let content = """
        # Daily Note
        - [x] Done task
        - [ ] First incomplete task
        - [ ] Second incomplete task
        """
        let result = NoteParser.firstUncheckedTodo(from: content)
        #expect(result == "First incomplete task")
    }

    @Test func returnsNilWhenAllChecked() {
        let content = """
        - [x] Done one
        - [x] Done two
        """
        let result = NoteParser.firstUncheckedTodo(from: content)
        #expect(result == nil)
    }

    @Test func returnsNilForEmptyContent() {
        let result = NoteParser.firstUncheckedTodo(from: "")
        #expect(result == nil)
    }

    @Test func returnsNilForNoTodos() {
        let content = """
        # Just a heading
        Some paragraph text.
        """
        let result = NoteParser.firstUncheckedTodo(from: content)
        #expect(result == nil)
    }

    @Test func handlesNestedTodos() {
        let content = """
        - [x] Parent done
            - [ ] Nested incomplete
        - [ ] Top level incomplete
        """
        let result = NoteParser.firstUncheckedTodo(from: content)
        #expect(result == "Nested incomplete")
    }

    @Test func trimsWhitespace() {
        let content = "- [ ]   Spacey task   "
        let result = NoteParser.firstUncheckedTodo(from: content)
        #expect(result == "Spacey task")
    }

    // MARK: - uncheckedTodos (multiple)

    @Test func returnsUpToThreeTodos() {
        let content = """
        - [ ] First
        - [ ] Second
        - [ ] Third
        - [ ] Fourth
        """
        let result = NoteParser.uncheckedTodos(from: content, limit: 3)
        #expect(result == ["First", "Second", "Third"])
    }

    @Test func returnsFewerThanLimitIfNotEnough() {
        let content = """
        - [x] Done
        - [ ] Only one
        """
        let result = NoteParser.uncheckedTodos(from: content, limit: 3)
        #expect(result == ["Only one"])
    }

    @Test func uncheckedTodosSkipsChecked() {
        let content = """
        - [ ] First
        - [x] Done
        - [ ] Second
        """
        let result = NoteParser.uncheckedTodos(from: content, limit: 3)
        #expect(result == ["First", "Second"])
    }

    // MARK: - extractLinks

    @Test func extractsMarkdownLinks() {
        let text = "Review [test plan](https://confluence.example.com/123) and update [ticket](https://jira.example.com/456)"
        let links = NoteParser.extractLinks(from: text)
        #expect(links.count == 2)
        #expect(links[0].text == "test plan")
        #expect(links[0].url == URL(string: "https://confluence.example.com/123")!)
        #expect(links[1].text == "ticket")
        #expect(links[1].url == URL(string: "https://jira.example.com/456")!)
    }

    @Test func returnsEmptyForNoLinks() {
        let links = NoteParser.extractLinks(from: "Just plain text")
        #expect(links.isEmpty)
    }

    // MARK: - displayText

    @Test func stripsMarkdownLinksFromDisplayText() {
        let text = "Review [test plan](https://example.com) now"
        let result = NoteParser.displayText(from: text)
        #expect(result == "Review test plan now")
    }

    @Test func displayTextPassesThroughPlainText() {
        let text = "No links here"
        let result = NoteParser.displayText(from: text)
        #expect(result == "No links here")
    }

    @Test func displayTextHandlesMultipleLinks() {
        let text = "[A](https://a.com) and [B](https://b.com)"
        let result = NoteParser.displayText(from: text)
        #expect(result == "A and B")
    }
}
