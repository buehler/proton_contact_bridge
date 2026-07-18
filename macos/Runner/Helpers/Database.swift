import Foundation
import OSLog

enum DatabaseError: Error {
    case groupNotAvailable
}

enum Database {
    private static let appGroupIdentifier = "group.ch.cbue.protonContactBridge"
    private static let databaseFilename = "contact_bridge.db"
    private static let logger = Logger(
        subsystem: "ch.cbue.protonContactBridge",
        category: "Database"
    )
    
    static func url() throws -> URL {
        Self.logger.debug("Resolving database path")
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            Self.logger.error(
                "Shared App Group container is unavailable"
            )
            throw DatabaseError.groupNotAvailable
        }
        return containerURL.appendingPathComponent(Self.databaseFilename)
    }
}
