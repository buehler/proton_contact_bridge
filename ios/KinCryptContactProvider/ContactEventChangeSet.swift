import Foundation

enum ContactEventCursorError: LocalizedError {
    case invalidEncoding
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "The contact event cursor is not UTF-8 encoded."
        case .invalidValue(let value):
            return "The contact event cursor is not a valid ULID: \(value)"
        }
    }
}

struct ContactEventCursor: Equatable, Comparable {
    static let minimum = try! ContactEventCursor(
        rawValue: "00000000000000000000000000"
    )

    let rawValue: String

    init(rawValue: String) throws {
        let validCharacters = CharacterSet(
            charactersIn: "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        )
        guard
            rawValue.utf8.count == 26,
            rawValue.unicodeScalars.allSatisfy(validCharacters.contains),
            let firstCharacter = rawValue.first,
            firstCharacter >= "0",
            firstCharacter <= "7"
        else {
            throw ContactEventCursorError.invalidValue(rawValue)
        }
        self.rawValue = rawValue
    }

    init(generationMarker: Data) throws {
        guard let rawValue = String(data: generationMarker, encoding: .utf8)
        else {
            throw ContactEventCursorError.invalidEncoding
        }
        try self.init(rawValue: rawValue)
    }

    var generationMarker: Data {
        Data(rawValue.utf8)
    }

    static func < (lhs: ContactEventCursor, rhs: ContactEventCursor) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ContactEventValue {
    let id: String
    let contactID: String
    let action: Int
}

enum ContactEventChangeSetError: LocalizedError {
    case invalidAction(Int)

    var errorDescription: String? {
        switch self {
        case .invalidAction(let action):
            return "A contact event has an invalid action: \(action)"
        }
    }
}

struct ContactEventChangeSet: Equatable {
    let upsertIdentifiers: [String]
    let deletedIdentifiers: [String]

    static func reduce(_ events: [ContactEventValue]) throws -> Self {
        enum State {
            case upsert
            case delete
        }

        var states: [String: State] = [:]
        for event in events {
            switch event.action {
            case 1:
                if states[event.contactID] != .delete {
                    states[event.contactID] = .upsert
                }
            case 2:
                states[event.contactID] = .delete
            default:
                throw ContactEventChangeSetError.invalidAction(event.action)
            }
        }

        return ContactEventChangeSet(
            upsertIdentifiers: states.compactMap { identifier, state in
                state == .upsert ? identifier : nil
            }.sorted(),
            deletedIdentifiers: states.compactMap { identifier, state in
                state == .delete ? identifier : nil
            }.sorted()
        )
    }
}
