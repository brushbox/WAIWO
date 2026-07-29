import Testing
import Foundation
@testable import WAIWO

struct NoteScannerTests {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    func makeTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "NoteScannerTests-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    func write(_ content: String, filename: String, in dir: String) throws {
        try content.write(toFile: dir + "/" + filename, atomically: true, encoding: .utf8)
    }

    var today: Date { Self.dateFormatter.date(from: "2026-07-29")! }

    @Test func happyPathProducesActiveTodoSnapshot() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try write(
            """
            # Today
            - [x] done thing
            - [ ] first [task](https://example.com)
            - [ ] second
            - [ ] third
            - [ ] fourth
            """,
            filename: "2026-07-29.md", in: dir
        )

        let snapshot = NoteScanner.scan(directory: dir, today: today)

        #expect(snapshot.displayState == .activeTodo(text: "first task"))
        #expect(snapshot.upcomingTodos == ["second", "third"])
        #expect(snapshot.currentLinks == [TodoLink(text: "task", url: URL(string: "https://example.com")!)])
        #expect(!snapshot.isStale)
        #expect(snapshot.notePath == dir + "/2026-07-29.md")
        #expect(snapshot.failureReason == nil)
    }

    @Test func staleNoteIsMarkedStaleWithItsDate() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try write("- [ ] old task", filename: "2026-07-27.md", in: dir)

        let snapshot = NoteScanner.scan(directory: dir, today: today)

        #expect(snapshot.displayState == .activeTodo(text: "old task"))
        #expect(snapshot.isStale)
        #expect(snapshot.noteDate == Self.dateFormatter.date(from: "2026-07-27"))
    }

    @Test func noUncheckedTodosGivesAllDone() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try write("- [x] everything finished", filename: "2026-07-29.md", in: dir)

        let snapshot = NoteScanner.scan(directory: dir, today: today)

        #expect(snapshot.displayState == .allDone)
        #expect(snapshot.upcomingTodos.isEmpty)
        #expect(snapshot.currentLinks.isEmpty)
        #expect(snapshot.notePath == dir + "/2026-07-29.md")
    }

    @Test func missingDirectoryGivesNoNotesFoundWithReason() {
        let snapshot = NoteScanner.scan(directory: "/nonexistent/waiwo-test-dir", today: today)

        #expect(snapshot.displayState == .noNotesFound)
        #expect(snapshot.upcomingTodos.isEmpty)
        #expect(snapshot.currentLinks.isEmpty)
        #expect(snapshot.notePath == nil)
        #expect(snapshot.failureReason != nil)
    }

    @Test func directoryWithoutDailyNotesGivesNoNotesFound() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try write("not a daily note", filename: "readme.md", in: dir)

        let snapshot = NoteScanner.scan(directory: dir, today: today)

        #expect(snapshot.displayState == .noNotesFound)
        #expect(snapshot.notePath == nil)
        #expect(snapshot.failureReason == "no matching note found")
    }

    @Test func unreadableChosenNoteStillCarriesNotePath() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        // A directory named like a daily note: chosen by NoteFinder, unreadable as a file.
        try FileManager.default.createDirectory(atPath: dir + "/2026-07-29.md", withIntermediateDirectories: true)

        let snapshot = NoteScanner.scan(directory: dir, today: today)

        #expect(snapshot.displayState == .noNotesFound)
        #expect(snapshot.notePath == dir + "/2026-07-29.md")
        #expect(snapshot.failureReason != nil)
    }
}

struct TodoStateApplyTests {
    @Test func applySetsEveryField() {
        let state = TodoState()
        let date = Date()

        state.apply(NoteSnapshot(
            displayState: .activeTodo(text: "task"),
            upcomingTodos: ["next"],
            currentLinks: [TodoLink(text: "a", url: URL(string: "https://a.example")!)],
            isStale: true,
            noteDate: date
        ))

        #expect(state.displayState == .activeTodo(text: "task"))
        #expect(state.upcomingTodos == ["next"])
        #expect(state.currentLinks.count == 1)
        #expect(state.isStale)
        #expect(state.noteDate == date)
    }

    @Test func failureSnapshotClearsStaleLinksAndUpcoming() {
        // The old field-by-field scan left upcomingTodos/currentLinks behind on
        // failure; atomic apply must clear them.
        let state = TodoState()
        state.apply(NoteSnapshot(
            displayState: .activeTodo(text: "task"),
            upcomingTodos: ["next"],
            currentLinks: [TodoLink(text: "a", url: URL(string: "https://a.example")!)],
            isStale: true,
            noteDate: Date()
        ))

        state.apply(NoteSnapshot(displayState: .noNotesFound, failureReason: "gone"))

        #expect(state.displayState == .noNotesFound)
        #expect(state.upcomingTodos.isEmpty)
        #expect(state.currentLinks.isEmpty)
        #expect(!state.isStale)
        #expect(state.noteDate == nil)
    }
}
