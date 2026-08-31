import Foundation

nonisolated struct MailAddress: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let userID: String
    let domainID: String
    let domainName: String
    let address: String
    let label: String?
    let isDefault: Bool
    let signature: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, address, label, signature
        case userID = "user_id"
        case domainID = "domain_id"
        case domainName = "domain_name"
        case isDefault = "is_default"
        case createdAt = "created_at"
    }
}

nonisolated struct AddressesResponse: Decodable, Sendable {
    let addresses: [MailAddress]
}

nonisolated struct SignatureUpdateRequest: Encodable, Sendable {
    let signature: String
}

nonisolated struct SignatureResponse: Decodable, Sendable {
    let ok: Bool
    let signature: String
}

nonisolated struct SignatureValueResponse: Decodable, Sendable {
    let signature: String
}

nonisolated struct DeviceSession: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let deviceName: String?
    let devicePlatform: String?
    let createdAt: Date
    let lastSeenAt: Date?
    let expiresAt: Date
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName = "device_name"
        case devicePlatform = "device_platform"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case expiresAt = "expires_at"
        case isCurrent = "is_current"
    }
}

nonisolated struct DevicesResponse: Decodable, Sendable {
    let devices: [DeviceSession]
}

nonisolated struct DownloadedAttachment: Equatable, Sendable {
    let fileURL: URL
    let filename: String
    let contentType: String
}
