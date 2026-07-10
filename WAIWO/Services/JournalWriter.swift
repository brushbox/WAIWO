import Foundation

enum JournalWriteError: Error {
    case directoryCreationFailed(Error)
    case writeFailed(Error)
}

enum JournalFormatter {
    static func format(text: String, now: Date) -> String {
        let formattedTime = formatTime(time: now)
        let (heading, body) = extractHeading(from: text)
        let trimmedBody = body.trimmingCharacters(in: .newlines)

        if !heading.isEmpty && trimmedBody.isEmpty {
            return "\n## \(formattedTime)\(heading)\n"
        } else if !heading.isEmpty {
            return "\n## \(formattedTime)\(heading)\n\n\(trimmedBody)\n"
        } else {
            return "\n## \(formattedTime)\n\n\(trimmedBody)\n"
        }
    }

    private static func formatTime(time: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }

    private static func extractHeading(from text: String) -> (heading: String, body: String) {
        if text.hasPrefix("## ") {
            let lines = text.split(separator: "\n", maxSplits: 1).map(String.init)
            let heading = lines[0].trimmingPrefix(while: { $0 == "#" || $0.isWhitespace })
                .trimmingCharacters(in: .whitespaces)
            var body = ""
            if lines.count > 1 {
                body = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return (heading: " \(heading)", body: body)
        } else {
            return (heading: "", body: text)
        }
    }
}

enum JournalWriter {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    // private static let timeFormatter: DateFormatter = {
    //     let f = DateFormatter()
    //     f.dateFormat = "HH:mm"
    //     f.timeZone = TimeZone.current
    //     return f
    // }()

    static func write(entry text: String, to directoryPath: String, now: Date = Date()) -> Result<
        Void, JournalWriteError
    > {
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(
                atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return .failure(.directoryCreationFailed(error))
        }

        let dateString = dateFormatter.string(from: now)
        // let timeString = timeFormatter.string(from: now)
        let filePath = (directoryPath as NSString).appendingPathComponent("\(dateString).md")

        let entry = JournalFormatter.format(text: text, now: now)
        // let (heading, body) = extractHeading(from: text)
        // let entry = "\n## \(timeString) \(heading)\n\n\(body)\n"
        // let entry = "\n## \(timeString)\n\n\(text)\n"

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
