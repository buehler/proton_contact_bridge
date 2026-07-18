import XCTest

final class RunnerTests: XCTestCase {
  func testUnicodeVCardUsesAppleCompatibleVCard3Encoding() throws {
    let vCard = """
    BEGIN:VCARD
    VERSION:4.0
    FN:Lorenz Bösch
    ADR:;;3 Mühlestrasse;Davos;;;Switzerland
    END:VCARD
    """

    let result = try XCTUnwrap(
      String(data: VCardCompatibility.appleCompatibleData(from: vCard), encoding: .utf8)
    )

    XCTAssertTrue(result.contains("VERSION:3.0"))
    XCTAssertTrue(result.contains("ADR;CHARSET=UTF-8:;;3 Mühlestrasse;Davos;;;Switzerland"))
    XCTAssertTrue(result.contains("FN;CHARSET=UTF-8:Lorenz Bösch"))
  }

  func testContactEventCursorRoundTripsULIDGenerationMarker() throws {
    let value = "01K33J5Y7A1B2C3D4E5F6G7H8J"
    let cursor = try ContactEventCursor(rawValue: value)

    XCTAssertEqual(
      try ContactEventCursor(generationMarker: cursor.generationMarker),
      cursor
    )
    XCTAssertEqual(ContactEventCursor.minimum.rawValue, String(repeating: "0", count: 26))
  }

  func testContactEventCursorRejectsMalformedAndOverflowValues() {
    XCTAssertThrowsError(try ContactEventCursor(rawValue: "legacy-json-marker"))
    XCTAssertThrowsError(
      try ContactEventCursor(rawValue: "81K33J5Y7A1B2C3D4E5F6G7H8J")
    )
    XCTAssertThrowsError(
      try ContactEventCursor(rawValue: "01k33j5y7a1b2c3d4e5f6g7h8j")
    )
  }

  func testContactEventChangeSetCollapsesDuplicateUpserts() throws {
    let changes = try ContactEventChangeSet.reduce([
      event("01K33J5Y7A1B2C3D4E5F6G7H8J", contactID: "b", action: 1),
      event("01K33J5Y7A1B2C3D4E5F6G7H8K", contactID: "b", action: 1),
      event("01K33J5Y7A1B2C3D4E5F6G7H8M", contactID: "a", action: 1),
    ])

    XCTAssertEqual(changes.upsertIdentifiers, ["a", "b"])
    XCTAssertEqual(changes.deletedIdentifiers, [])
  }

  func testContactEventChangeSetGivesDeleteFinalPrecedence() throws {
    let changes = try ContactEventChangeSet.reduce([
      event("01K33J5Y7A1B2C3D4E5F6G7H8J", contactID: "upsert-delete", action: 1),
      event("01K33J5Y7A1B2C3D4E5F6G7H8K", contactID: "upsert-delete", action: 2),
      event("01K33J5Y7A1B2C3D4E5F6G7H8M", contactID: "delete-upsert", action: 2),
      event("01K33J5Y7A1B2C3D4E5F6G7H8N", contactID: "delete-upsert", action: 1),
    ])

    XCTAssertEqual(changes.upsertIdentifiers, [])
    XCTAssertEqual(
      changes.deletedIdentifiers,
      ["delete-upsert", "upsert-delete"]
    )
  }

  func testContactEventChangeSetRejectsInvalidAction() {
    XCTAssertThrowsError(
      try ContactEventChangeSet.reduce([
        event("01K33J5Y7A1B2C3D4E5F6G7H8J", contactID: "a", action: 3)
      ])
    )
  }

  private func event(
    _ id: String,
    contactID: String,
    action: Int
  ) -> ContactEventValue {
    ContactEventValue(id: id, contactID: contactID, action: action)
  }
}
