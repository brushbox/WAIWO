import Testing
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
}
