import Foundation

enum PathConfig {
    static let storageKeyNotes = "path_dailyNotes"
    static let storageKeyJournal = "path_journal"

    static var defaultNotesPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent(
            "Library/Mobile Documents/iCloud~md~obsidian/Documents/Pete/TODOs"
        )
    }

    static var defaultJournalPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent(
            "Library/Mobile Documents/iCloud~md~obsidian/Documents/Pete/Daily Journal"
        )
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            storageKeyNotes: defaultNotesPath,
            storageKeyJournal: defaultJournalPath,
        ])
    }

    static func readNotesPath() -> String {
        UserDefaults.standard.string(forKey: storageKeyNotes) ?? defaultNotesPath
    }

    static func readJournalPath() -> String {
        UserDefaults.standard.string(forKey: storageKeyJournal) ?? defaultJournalPath
    }

    static func writeNotesPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: storageKeyNotes)
    }

    static func writeJournalPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: storageKeyJournal)
    }
}
