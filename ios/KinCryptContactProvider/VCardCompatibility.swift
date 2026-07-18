import Foundation

enum VCardCompatibility {
    static func appleCompatibleData(from vCard: String) -> Data {
        let compatibleLines = unfoldedLines(from: vCard).map { line in
            addUTF8CharsetIfNeeded(to: vCard3Line(from: line))
        }
        return Data(compatibleLines.joined(separator: "\r\n").utf8)
    }

    static func embeddedPhotoData(from vCard: String) -> Data? {
        for line in unfoldedLines(from: vCard) {
            guard let separator = valueSeparator(in: line) else {
                continue
            }

            let header = line[..<separator]
            let propertyWithGroup = header.split(
                separator: ";",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )[0]
            guard
                propertyWithGroup.split(
                    separator: ".",
                    omittingEmptySubsequences: false
                ).last?.caseInsensitiveCompare("PHOTO") == .orderedSame
            else {
                continue
            }

            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\,", with: ",")
            guard
                value.range(
                    of: "data:image/",
                    options: [.anchored, .caseInsensitive]
                ) != nil,
                let comma = value.firstIndex(of: ",")
            else {
                continue
            }

            let metadata = value[..<comma]
            let parameters = metadata.split(
                separator: ";",
                omittingEmptySubsequences: false
            )
            guard parameters.dropFirst().contains(where: {
                $0.caseInsensitiveCompare("base64") == .orderedSame
            }) else {
                continue
            }

            let payload = value[value.index(after: comma)...]
            let compactPayload = payload.filter { !$0.isWhitespace }
            guard
                !compactPayload.isEmpty,
                let data = Data(base64Encoded: String(compactPayload))
            else {
                continue
            }
            return data
        }
        return nil
    }

    private static func unfoldedLines(from vCard: String) -> [String] {
        let normalizedNewlines = vCard
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let physicalLines = normalizedNewlines.components(separatedBy: "\n")

        var unfoldedLines: [String] = []
        unfoldedLines.reserveCapacity(physicalLines.count)
        for line in physicalLines {
            if
                (line.hasPrefix(" ") || line.hasPrefix("\t")),
                !unfoldedLines.isEmpty
            {
                unfoldedLines[unfoldedLines.count - 1].append(
                    contentsOf: line.dropFirst()
                )
            } else {
                unfoldedLines.append(line)
            }
        }
        return unfoldedLines
    }

    private static func vCard3Line(from line: String) -> String {
        line.caseInsensitiveCompare("VERSION:4.0") == .orderedSame
            ? "VERSION:3.0"
            : line
    }

    private static func addUTF8CharsetIfNeeded(to line: String) -> String {
        guard let separator = valueSeparator(in: line) else {
            return line
        }

        let header = line[..<separator]
        let value = line[line.index(after: separator)...]
        guard value.unicodeScalars.contains(where: { $0.value > 0x7f }) else {
            return line
        }
        guard header.range(of: "CHARSET=", options: .caseInsensitive) == nil else {
            return line
        }

        let propertyWithGroup = header.split(
            separator: ";",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )[0]
        let property = propertyWithGroup.split(
            separator: ".",
            omittingEmptySubsequences: false
        ).last?.uppercased()
        guard let property, utf8TextProperties.contains(property) else {
            return line
        }

        return "\(header);CHARSET=UTF-8:\(value)"
    }

    private static func valueSeparator(in line: String) -> String.Index? {
        var isInsideQuotes = false
        var isEscaped = false

        for index in line.indices {
            let character = line[index]
            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isInsideQuotes.toggle()
            } else if character == ":", !isInsideQuotes {
                return index
            }
        }
        return nil
    }

    private static let utf8TextProperties: Set<String> = [
        "ADR",
        "CATEGORIES",
        "EMAIL",
        "FN",
        "LABEL",
        "N",
        "NICKNAME",
        "NOTE",
        "ORG",
        "PRODID",
        "ROLE",
        "SORT-STRING",
        "TEL",
        "TITLE",
    ]
}
