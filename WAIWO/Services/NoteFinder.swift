import Foundation

struct NoteFinderResult {
    let filename: String
    let date: Date
    let isStale: Bool
}

enum NoteFinder {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    static func bestNote(from filenames: [String], today: Date) -> NoteFinderResult? {
        let todayStart = Calendar.current.startOfDay(for: today)

        let candidates: [(String, Date)] = filenames.compactMap { filename in
            let name = filename.replacingOccurrences(of: ".md", with: "")
            guard let date = dateFormatter.date(from: name) else { return nil }
            let dateStart = Calendar.current.startOfDay(for: date)
            guard dateStart <= todayStart else { return nil }
            return (filename, dateStart)
        }

        guard let best = candidates.max(by: { $0.1 < $1.1 }) else { return nil }

        let isStale = Calendar.current.startOfDay(for: best.1) != todayStart
        return NoteFinderResult(filename: best.0, date: best.1, isStale: isStale)
    }
}
