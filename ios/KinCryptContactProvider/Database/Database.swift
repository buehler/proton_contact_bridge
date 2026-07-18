import Foundation
import GRDB
import OSLog

enum ContactProviderDatabaseError: LocalizedError {
    case appGroupUnavailable
    case databaseMissing
    case foreignKeysDisabled
    case unexpectedJournalMode(String?)

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "The shared App Group container is unavailable."
        case .databaseMissing:
            return "The shared contacts database does not exist."
        case .foreignKeysDisabled:
            return "SQLite foreign-key enforcement is disabled."
        case .unexpectedJournalMode(let mode):
            return "The shared contacts database is not in WAL mode (found \(mode ?? "unknown"))."
        }
    }
}

enum Database {
    private static let appGroupIdentifier = "group.ch.cbue.protonContactBridge"
    private static let databaseFilename = "contact_bridge.db"

    static func open() throws -> DatabaseQueue {
        ContactProviderLog.database.debug("Resolving shared database")
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            ContactProviderLog.database.error(
                "Shared App Group container is unavailable"
            )
            throw ContactProviderDatabaseError.appGroupUnavailable
        }

        let databaseURL = containerURL.appendingPathComponent(databaseFilename)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            ContactProviderLog.database.error("Shared database is missing")
            throw ContactProviderDatabaseError.databaseMissing
        }

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true

        let databaseQueue = try DatabaseQueue(
            path: databaseURL.path,
            configuration: configuration
        )
        ContactProviderLog.database.debug("Opened shared database")

        do {
            try databaseQueue.read { database in
                let foreignKeysEnabled = try Int.fetchOne(
                    database,
                    sql: "PRAGMA foreign_keys"
                )
                guard foreignKeysEnabled == 1 else {
                    throw ContactProviderDatabaseError.foreignKeysDisabled
                }

                let journalMode = try String.fetchOne(
                    database,
                    sql: "PRAGMA journal_mode"
                )
                guard journalMode?.lowercased() == "wal" else {
                    throw ContactProviderDatabaseError.unexpectedJournalMode(
                        journalMode
                    )
                }
            }
            ContactProviderLog.database.notice(
                "Validated foreign keys and WAL journal mode"
            )
        } catch {
            ContactProviderLog.database.error(
                "Database validation failed: \(error.localizedDescription, privacy: .public)"
            )
            try? databaseQueue.close()
            throw error
        }

        return databaseQueue
    }
}
