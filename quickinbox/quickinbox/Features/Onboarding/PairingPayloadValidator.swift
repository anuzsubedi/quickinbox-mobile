import Foundation

nonisolated struct ValidatedPairingPayload: Equatable, Sendable {
    let origin: URL
    let code: String
}

nonisolated enum PairingPayloadValidator {
    private static let maximumPayloadBytes = 2_048
    private static let expectedKeys: Set<String> = ["version", "origin", "code"]

    static func validate(scannedValue: String) throws -> ValidatedPairingPayload {
        guard let data = scannedValue.data(using: .utf8),
              !data.isEmpty,
              data.count <= maximumPayloadBytes,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              Set(dictionary.keys) == expectedKeys,
              let version = dictionary["version"] as? Int,
              version == 1,
              let rawOrigin = dictionary["origin"] as? String,
              let code = dictionary["code"] as? String else {
            throw APIError.invalidPairingPayload
        }

        return try validate(origin: rawOrigin, code: code)
    }

    static func validate(origin rawOrigin: String, code rawCode: String) throws -> ValidatedPairingPayload {
        let origin = try OriginValidator.validate(rawOrigin)
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard code.count == 22,
              code.utf8.allSatisfy({ byte in
                  (65...90).contains(byte)
                      || (97...122).contains(byte)
                      || (48...57).contains(byte)
                      || byte == 95
                      || byte == 45
              }) else {
            throw APIError.invalidPairingPayload
        }

        return ValidatedPairingPayload(origin: origin, code: code)
    }
}
