import Foundation

nonisolated struct MessageTextParts: Equatable, Sendable {
    let message: String
    let quotedHistory: String?
}

/// Splits the common plain-text reply formats without discarding unfamiliar content.
nonisolated enum QuotedTextParser {
    static func split(_ source: String) -> MessageTextParts {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        guard let boundary = quoteBoundary(in: lines), boundary > 0 else {
            return MessageTextParts(message: normalized.trimmed, quotedHistory: nil)
        }

        let message = lines[..<boundary].joined(separator: "\n").trimmed
        let history = lines[boundary...].joined(separator: "\n").trimmed
        guard !message.isEmpty, !history.isEmpty else {
            return MessageTextParts(message: normalized.trimmed, quotedHistory: nil)
        }
        return MessageTextParts(message: message, quotedHistory: history)
    }

    private static func quoteBoundary(in lines: [String]) -> Int? {
        for index in lines.indices {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            let lowercase = line.lowercased()

            if line.hasPrefix(">") || lowercase == "-----original message-----" {
                return index
            }

            if lowercase.hasPrefix("on "), lowercase.hasSuffix(" wrote:") {
                return index
            }

            // Header-style history used by Outlook and many transactional mailers.
            if lowercase.hasPrefix("from:"), headerBlockStarts(at: index, in: lines) {
                return index
            }
        }
        return nil
    }

    private static func headerBlockStarts(at index: Int, in lines: [String]) -> Bool {
        let end = min(lines.count, index + 6)
        let headers = lines[index..<end].map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        let hasRecipient = headers.contains { $0.hasPrefix("to:") }
        let hasDate = headers.contains { $0.hasPrefix("date:") || $0.hasPrefix("sent:") }
        let hasSubject = headers.contains { $0.hasPrefix("subject:") }
        return hasRecipient && (hasDate || hasSubject)
    }
}

private nonisolated extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
