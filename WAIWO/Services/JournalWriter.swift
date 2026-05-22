import Foundation

enum JournalWriteError: Error {
    case directoryCreationFailed(Error)
    case writeFailed(Error)
}

enum JournalWriter {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone.current
        return f
    }()

    static func write(entry text: String, to directoryPath: String, now: Date = Date()) -> Result<Void, JournalWriteError> {
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return .failure(.directoryCreationFailed(error))
        }

        let dateString = dateFormatter.string(from: now)
        let timeString = timeFormatter.string(from: now)
        let filePath = (directoryPath as NSString).appendingPathComponent("\(dateString).md")

        let entry = "\n## \(timeString)\n\n\(text)\n"

        do {
            if fileManager.fileExists(atPath: filePath) {
                var content = try String(contentsOfFile: filePath, encoding: .utf8)
                content += entry
                try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            } else {
                let content = String(entry.dropFirst())
                try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            }
        } catch {
            return .failure(.writeFailed(error))
        }

        return .success(())
    }
}