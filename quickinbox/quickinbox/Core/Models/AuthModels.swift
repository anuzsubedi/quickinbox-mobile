import Foundation

nonisolated struct PairingPayload: Codable, Sendable {
    let version: Int
    let origin: String
    let code: String

    var isSupported: Bool { version == 1 }
}

nonisolated struct PairingRequest: Encodable, Sendable {
    let code: String
    let deviceName: String
    let platform: String = "ios"
}

nonisolated struct PairingResponse: Decodable, Sendable {
    let token: String
    let expiresAt: Date
}

nonisolated struct Credential: Codable, Equatable, Sendable {
    let origin: URL
    let token: String
    let expiresAt: Date
    let cachedUser: User?

    var isExpired: Bool { expiresAt <= Date() }

    init(origin: URL, token: String, expiresAt: Date, cachedUser: User? = nil) {
        self.origin = origin
        self.token = token
        self.expiresAt = expiresAt
        self.cachedUser = cachedUser
    }

    func caching(user: User) -> Credential {
        Credential(origin: origin, token: token, expiresAt: expiresAt, cachedUser: user)
    }
}

nonisolated struct CurrentUserResponse: Decodable, Sendable {
    let user: User
}

nonisolated struct User: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let name: String
    let isAdmin: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case isAdmin = "is_admin"
        case createdAt = "created_at"
    }
}
