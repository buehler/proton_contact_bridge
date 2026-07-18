//
//  KinCryptContactProviderRootContainerEnumerator.swift
//  KinCryptContactProvider
//
//  Created by christoph on 16.08.2026.
//

import ContactProvider
import Foundation
import GRDB
import OSLog

private enum ContactEventEnumerationError: LocalizedError {
    case missingContact(String)

    var errorDescription: String? {
        switch self {
        case .missingContact(let identifier):
            return "An upsert event references a missing contact: \(identifier)"
        }
    }
}

actor KinCryptContactProviderRootContainerEnumerator: ContactItemEnumerator {
    private struct Snapshot {
        let cursor: ContactEventCursor
        let items: [ContactItem]
    }

    private struct ChangeSnapshot {
        let cursor: ContactEventCursor
        let updatedItems: [ContactItem]
        let deletedIdentifiers: [ContactItem.Identifier]
    }

    private struct ContactEventRecord: FetchableRecord {
        let id: String
        let contactID: String
        let action: Int

        init(row: Row) {
            id = row["id"]
            contactID = row["contact_id"]
            action = row["action"]
        }

        var value: ContactEventValue {
            ContactEventValue(id: id, contactID: contactID, action: action)
        }
    }

    private var databaseQueue: DatabaseQueue?
    private var snapshot: Snapshot?
    private var invalidated = false

    func enumerateContent(
        in page: ContactItemPage,
        for observer: ContactItemContentObserver
    ) async {
        do {
            guard !invalidated else {
                ContactProviderLog.enumeration.error(
                    "Content enumeration requested after invalidation"
                )
                throw ContactProviderError.extensionInvalidated
            }

            let currentSnapshot: Snapshot
            if page == .initialPage {
                ContactProviderLog.enumeration.notice(
                    "Starting full contact snapshot"
                )
                snapshot = nil
                currentSnapshot = try loadSnapshot()
                snapshot = currentSnapshot
            } else {
                guard
                    let snapshot,
                    page.generationMarker == snapshot.cursor.generationMarker,
                    page.offset >= 0,
                    page.offset <= snapshot.items.count
                else {
                    ContactProviderLog.enumeration.error(
                        "Rejected expired page at offset \(page.offset, privacy: .public)"
                    )
                    throw ContactProviderError.pageExpired
                }
                currentSnapshot = snapshot
            }

            let batchSize = max(1, observer.suggestedPageSize)
            let remainingCount = currentSnapshot.items.count - page.offset
            let endOffset = page.offset + min(batchSize, remainingCount)
            let items = Array(
                currentSnapshot.items[page.offset..<endOffset]
            )

            if !items.isEmpty {
                observer.didEnumerate(items)
            }
            ContactProviderLog.enumeration.debug(
                "Enumerated \(items.count, privacy: .public) contacts at offset \(page.offset, privacy: .public)"
            )

            if endOffset < currentSnapshot.items.count {
                let nextPage = ContactItemPage(
                    generationMarker: currentSnapshot.cursor.generationMarker,
                    offset: endOffset
                )
                observer.didFinishEnumeratingPage(upTo: nextPage)
                ContactProviderLog.enumeration.debug(
                    "Finished page; next offset is \(endOffset, privacy: .public)"
                )
            } else {
                observer.didFinishEnumeratingContent(
                    upTo: currentSnapshot.cursor.generationMarker
                )
                snapshot = nil
                ContactProviderLog.enumeration.notice(
                    "Finished full snapshot with \(currentSnapshot.items.count, privacy: .public) contacts"
                )
                cleanupEventsNonfatally(through: currentSnapshot.cursor)
            }
        } catch {
            ContactProviderLog.enumeration.error(
                "Content enumeration failed: \(error.localizedDescription, privacy: .public)"
            )
            observer.didFinishEnumeratingContentWithError(error)
        }
    }

    func enumerateChanges(
        startingAt syncAnchor: ContactItemSyncAnchor,
        for observer: ContactItemChangeObserver
    ) async {
        do {
            guard !invalidated else {
                ContactProviderLog.enumeration.error(
                    "Change enumeration requested after invalidation"
                )
                throw ContactProviderError.extensionInvalidated
            }

            let startingCursor = try cursor(from: syncAnchor)
            let changes = try loadChanges(startingAfter: startingCursor)
            let batchSize = max(1, observer.suggestedBatchSize)
            enumerateBatches(
                changes.updatedItems,
                batchSize: batchSize,
                observer.didUpdate
            )
            enumerateBatches(
                changes.deletedIdentifiers,
                batchSize: batchSize,
                observer.didDelete
            )

            let nextAnchor = ContactItemSyncAnchor(
                generationMarker: changes.cursor.generationMarker,
                offset: 0
            )
            snapshot = nil
            observer.didFinishEnumeratingChanges(
                upTo: nextAnchor,
                moreComing: false
            )
            ContactProviderLog.enumeration.notice(
                "Finished change enumeration with \(changes.updatedItems.count, privacy: .public) upserts and \(changes.deletedIdentifiers.count, privacy: .public) deletions"
            )
            cleanupEventsNonfatally(through: changes.cursor)
        } catch {
            ContactProviderLog.enumeration.error(
                "Change enumeration failed: \(error.localizedDescription, privacy: .public)"
            )
            observer.didFinishEnumeratingChangesWithError(error)
        }
    }

    func invalidate() async {
        invalidated = true
        snapshot = nil
        if let databaseQueue {
            try? databaseQueue.close()
            self.databaseQueue = nil
            ContactProviderLog.database.debug("Closed shared database")
        }
    }

    private func loadSnapshot() throws -> Snapshot {
        ContactProviderLog.enumeration.debug("Loading contact rows")
        let databaseQueue = try database()
        let snapshot = try databaseQueue.read { database in
            let cursor = try maximumEventCursor(
                in: database,
                noEarlierThan: .minimum
            )
            let records = try ContactRecord.fetchAll(
                database,
                sql: """
                    SELECT id, decrypted_v_card
                    FROM contacts
                    ORDER BY id
                """
            )
            return Snapshot(
                cursor: cursor,
                items: try contactItems(from: records)
            )
        }
        ContactProviderLog.enumeration.debug(
            "Fetched \(snapshot.items.count, privacy: .public) contact rows"
        )
        return snapshot
    }

    private func loadChanges(
        startingAfter startingCursor: ContactEventCursor
    ) throws -> ChangeSnapshot {
        ContactProviderLog.enumeration.debug(
            "Loading contact events after \(startingCursor.rawValue, privacy: .public)"
        )
        let databaseQueue = try database()
        return try databaseQueue.read { database in
            let upperBoundary = try maximumEventCursor(
                in: database,
                noEarlierThan: startingCursor
            )
            let events = try ContactEventRecord.fetchAll(
                database,
                sql: """
                    SELECT id, contact_id, action
                    FROM contact_events
                    WHERE id > ? AND id <= ?
                    ORDER BY id
                """,
                arguments: [
                    startingCursor.rawValue,
                    upperBoundary.rawValue,
                ]
            )
            for event in events {
                _ = try ContactEventCursor(rawValue: event.id)
            }
            let changeSet = try ContactEventChangeSet.reduce(
                events.map(\.value)
            )
            let records = try contactRecords(
                withIdentifiers: changeSet.upsertIdentifiers,
                in: database
            )

            var recordsByIdentifier: [String: ContactRecord] = [:]
            for record in records {
                if let identifier = record.id {
                    recordsByIdentifier[identifier] = record
                }
            }

            let updatedItems = try changeSet.upsertIdentifiers.map {
                identifier in
                guard let record = recordsByIdentifier[identifier] else {
                    throw ContactEventEnumerationError.missingContact(
                        identifier
                    )
                }
                return try record.contactItem()
            }

            return ChangeSnapshot(
                cursor: upperBoundary,
                updatedItems: updatedItems,
                deletedIdentifiers: changeSet.deletedIdentifiers.map(
                    ContactItem.Identifier.init
                )
            )
        }
    }

    private func maximumEventCursor(
        in database: GRDB.Database,
        noEarlierThan minimum: ContactEventCursor
    ) throws -> ContactEventCursor {
        guard
            let value = try String.fetchOne(
                database,
                sql: "SELECT MAX(id) FROM contact_events"
            )
        else {
            return minimum
        }
        let cursor = try ContactEventCursor(rawValue: value)
        return max(cursor, minimum)
    }

    private func contactRecords(
        withIdentifiers identifiers: [String],
        in database: GRDB.Database
    ) throws -> [ContactRecord] {
        let queryLimit = 500
        var records: [ContactRecord] = []
        records.reserveCapacity(identifiers.count)

        var offset = 0
        while offset < identifiers.count {
            let endOffset = min(offset + queryLimit, identifiers.count)
            let identifiers = identifiers[offset..<endOffset]
            let placeholders = Array(
                repeating: "?",
                count: identifiers.count
            ).joined(separator: ", ")
            records.append(
                contentsOf: try ContactRecord.fetchAll(
                    database,
                    sql: """
                        SELECT id, decrypted_v_card
                        FROM contacts
                        WHERE id IN (\(placeholders))
                        ORDER BY id
                    """,
                    arguments: StatementArguments(identifiers)
                )
            )
            offset = endOffset
        }
        return records
    }

    private func contactItems(from records: [ContactRecord]) throws
        -> [ContactItem]
    {
        try records.enumerated().map { index, record in
            do {
                return try record.contactItem()
            } catch {
                ContactProviderLog.enumeration.error(
                    "Failed to parse contact row at index \(index, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        }
    }

    private func cursor(from syncAnchor: ContactItemSyncAnchor) throws
        -> ContactEventCursor
    {
        guard syncAnchor.offset == 0 else {
            throw ContactProviderError.changeAnchorExpired
        }
        do {
            return try ContactEventCursor(
                generationMarker: syncAnchor.generationMarker
            )
        } catch {
            ContactProviderLog.enumeration.notice(
                "Rejected a legacy or malformed change anchor"
            )
            throw ContactProviderError.changeAnchorExpired
        }
    }

    private func cleanupEventsNonfatally(through cursor: ContactEventCursor) {
        do {
            let databaseQueue = try database()
            let deletedCount = try databaseQueue.write { database in
                try database.execute(
                    sql: "DELETE FROM contact_events WHERE id <= ?",
                    arguments: [cursor.rawValue]
                )
                return database.changesCount
            }
            ContactProviderLog.database.debug(
                "Deleted \(deletedCount, privacy: .public) processed contact events through \(cursor.rawValue, privacy: .public)"
            )
        } catch {
            ContactProviderLog.database.error(
                "Failed to clean up processed contact events: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func enumerateBatches<Item>(
        _ items: [Item],
        batchSize: Int,
        _ enumerate: ([Item]) -> Void
    ) {
        var offset = 0
        while offset < items.count {
            let endOffset = min(offset + batchSize, items.count)
            enumerate(Array(items[offset..<endOffset]))
            offset = endOffset
        }
    }

    private func database() throws -> DatabaseQueue {
        if let databaseQueue {
            return databaseQueue
        }

        let databaseQueue = try Database.open()
        self.databaseQueue = databaseQueue
        return databaseQueue
    }
}
