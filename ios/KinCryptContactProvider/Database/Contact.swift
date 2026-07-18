import ContactProvider
import Contacts
import Foundation
import GRDB

enum ContactRecordError: LocalizedError {
    case missingIdentifier
    case missingVCard
    case invalidVCard
    case unexpectedContactCount(Int)
    case mutableCopyFailed

    var errorDescription: String? {
        switch self {
        case .missingIdentifier:
            return "A contact row has no identifier."
        case .missingVCard:
            return "A contact row has no decrypted vCard."
        case .invalidVCard:
            return "A decrypted contact vCard is invalid."
        case .unexpectedContactCount(let count):
            return "A contact row produced \(count) native contacts instead of one."
        case .mutableCopyFailed:
            return "A parsed native contact could not be made mutable."
        }
    }
}

struct ContactRecord: FetchableRecord {
    let id: String?
    let decryptedVCard: String?

    init(row: Row) {
        id = row[Columns.id]
        decryptedVCard = row[Columns.decryptedVCard]
    }

    func contactItem() throws -> ContactItem {
        guard let id, !id.isEmpty else {
            throw ContactRecordError.missingIdentifier
        }
        guard
            let decryptedVCard,
            !decryptedVCard.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        else {
            throw ContactRecordError.missingVCard
        }

        let nativeContacts: [CNContact]
        do {
            nativeContacts = try CNContactVCardSerialization.contacts(
                with: VCardCompatibility.appleCompatibleData(from: decryptedVCard)
            )
        } catch {
            throw ContactRecordError.invalidVCard
        }

        guard nativeContacts.count == 1 else {
            throw ContactRecordError.unexpectedContactCount(
                nativeContacts.count
            )
        }
        guard
            let mutableContact = nativeContacts[0].mutableCopy()
                as? CNMutableContact
        else {
            throw ContactRecordError.mutableCopyFailed
        }

        if let imageData = VCardCompatibility.embeddedPhotoData(
            from: decryptedVCard
        ) {
            mutableContact.imageData = imageData
        }

        return .contact(mutableContact, ContactItem.Identifier(id))
    }

    private enum Columns {
        static let id = Column("id")
        static let decryptedVCard = Column("decrypted_v_card")
    }
}
