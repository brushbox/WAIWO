import Testing
import Foundation
@testable import WAIWO

struct NoteFinderTests {
    private func makeDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)!
    }

    @Test func findsTodaysNote() {
        let today = makeDate("2026-04-23")
        let filenames = ["2026-04-21.md", "2026-04-22.md", "2026-04-23.md"]
        let result = NoteFinder.bestNote(from: filenames, today: today)
        #expect(result?.filename == "2026-04-23.md")
        #expect(result?.isStale == false)
    }

    @Test func fallsBackToMostRecent() {
        let today = makeDate("2026-04-23")
        let filenames = ["2026-04-20.md", "2026-04-21.md"]
        let result = NoteFinder.bestNote(from: filenames, today: today)
        #expect(result?.filename == "2026-04-21.md")
        #expect(result?.isStale == true)
    }

    @Test func returnsNilForEmptyList() {
        let today = makeDate("2026-04-23")
        let result = NoteFinder.bestNote(from: [], today: today)
        #expect(result == nil)
    }

    @Test func ignoresNonDateFilenames() {
        let today = makeDate("2026-04-23")
        let filenames = ["notes.md", "readme.md", "2026-04-22.md"]
        let result = NoteFinder.bestNote(from: filenames, today: today)
        #expect(result?.filename == "2026-04-22.md")
        #expect(result?.isStale == true)
    }

    @Test func ignoresFutureDates() {
        let today = makeDate("2026-04-23")
        let filenames = ["2026-04-24.md", "2026-04-22.md"]
        let result = NoteFinder.bestNote(from: filenames, today: today)
        #expect(result?.filename == "2026-04-22.md")
        #expect(result?.isStale == true)
    }

    @Test func parsesDateFromFilename() {
        let today = makeDate("2026-04-23")
        let filenames = ["2026-04-23.md"]
        let result = NoteFinder.bestNote(from: filenames, today: today)
        #expect(result?.date == today)
    }
}
