import Testing
import Foundation
@testable import WAIWO

struct NoteWriterTests {
    private func makeDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)!
    }

    @Test func prependsTodoToLatestNote() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try "- [ ] Existing task\n".write(toFile: "\(tempDir)/2026-04-22.md", atomically: true, encoding: .utf8)
        try "- [ ] Another task\n".write(toFile: "\(tempDir)/2026-04-23.md", atomically: true, encoding: .utf8)

        let date = makeDate("2026-04-23")
        let result = NoteWriter.write(todo: "New todo", to: tempDir, today: date)
        try result.get()

        let content = try String(contentsOfFile: "\(tempDir)/2026-04-23.md", encoding: .utf8)
        #expect(content == "- [ ] New todo\n- [ ] Another task\n")
    }

    @Test func prependsToStaleNoteWhenNoTodayNote() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try "- [ ] Old task\n".write(toFile: "\(tempDir)/2026-04-21.md", atomically: true, encoding: .utf8)

        let date = makeDate("2026-04-23")
        let result = NoteWriter.write(todo: "New todo", to: tempDir, today: date)
        try result.get()

        let content = try String(contentsOfFile: "\(tempDir)/2026-04-21.md", encoding: .utf8)
        #expect(content == "- [ ] New todo\n- [ ] Old task\n")
    }

    @Test func returnsErrorWhenNoNotesExist() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let date = makeDate("2026-04-23")
        let result = NoteWriter.write(todo: "New todo", to: tempDir, today: date)

        if case .success = result {
            Issue.record("Expected failure but got success")
        }
    }

    @Test func returnsErrorForMissingDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path

        let date = makeDate("2026-04-23")
        let result = NoteWriter.write(todo: "New todo", to: tempDir, today: date)

        if case .success = result {
            Issue.record("Expected failure but got success")
        }
    }

    @Test func handlesEmptyFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try "".write(toFile: "\(tempDir)/2026-04-23.md", atomically: true, encoding: .utf8)

        let date = makeDate("2026-04-23")
        let result = NoteWriter.write(todo: "New todo", to: tempDir, today: date)
        try result.get()

        let content = try String(contentsOfFile: "\(tempDir)/2026-04-23.md", encoding: .utf8)
        #expect(content == "- [ ] New todo\n")
    }
}

struct JournalWriterTests {
    private func makeDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)!
    }

    @Test func createsFileWhenNoneExists() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let now = makeDate("2026-04-23 10:30")
        let result = JournalWriter.write(entry: "Wrote some code.", to: tempDir, now: now)
        try result.get()

        let content = try String(contentsOfFile: "\(tempDir)/2026-04-23.md", encoding: .utf8)
        #expect(content == "## 10:30\n\nWrote some code.\n")
    }

    @Test func appendsToExistingFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        try "## 09:00\n\nMorning entry.\n".write(toFile: "\(tempDir)/2026-04-23.md", atomically: true, encoding: .utf8)

        let now = makeDate("2026-04-23 14:30")
        let result = JournalWriter.write(entry: "Afternoon entry.", to: tempDir, now: now)
        try result.get()

        let content = try String(contentsOfFile: "\(tempDir)/2026-04-23.md", encoding: .utf8)
        #expect(content == "## 09:00\n\nMorning entry.\n\n## 14:30\n\nAfternoon entry.\n")
    }

    @Test func createsDirectoryIfNeeded() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let now = makeDate("2026-04-23 10:00")
        let result = JournalWriter.write(entry: "Test entry.", to: tempDir, now: now)
        try result.get()

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: tempDir, isDirectory: &isDir)
        #expect(exists)
        #expect(isDir.boolValue)
    }

    @Test func preservesExistingEntriesAcrossDays() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let day1 = makeDate("2026-04-22 10:00")
        let result1 = JournalWriter.write(entry: "Day 1 entry.", to: tempDir, now: day1)
        try result1.get()

        let day2 = makeDate("2026-04-23 11:00")
        let result2 = JournalWriter.write(entry: "Day 2 entry.", to: tempDir, now: day2)
        try result2.get()

        let content1 = try String(contentsOfFile: "\(tempDir)/2026-04-22.md", encoding: .utf8)
        #expect(content1 == "## 10:00\n\nDay 1 entry.\n")

        let content2 = try String(contentsOfFile: "\(tempDir)/2026-04-23.md", encoding: .utf8)
        #expect(content2 == "## 11:00\n\nDay 2 entry.\n")
    }
}