import Foundation

enum TodoWriteError: Error {
    case noNotesFound
    case writeFailed(Error)
}

enum NoteWriter {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    static func write(todo text: String, to directoryPath: String, today: Date = Date()) -> Result<Void, TodoWriteError> {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: directoryPath) else {
            return .failure(.noNotesFound)
        }

        guard let result = NoteFinder.bestNote(from: files, today: today) else {
            return .failure(.noNotesFound)
        }

        let filePath = (directoryPath as NSString).appendingPathComponent(result.filename)

        do {
            var content = try String(contentsOfFile: filePath, encoding: .utf8)
            let insertion = "- [ ] \(text)\n"
            content = insertion + content
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.writeFailed(error))
        }

        return .success(())
    }
}