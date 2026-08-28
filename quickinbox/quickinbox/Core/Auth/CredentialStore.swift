import Foundation
import Security

actor CredentialStore {
    private let service: String
    private let account = "mobile-session"

    init(service: String = Bundle.main.bundleIdentifier ?? "QuickInbox") {
        self.service = service
    }

    func load() throws -> Credential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CredentialStoreError.keychain(status)
        }

        do {
            return try JSONDecoder().decode(Credential.self, from: data)
        } catch {
            try? delete()
            throw CredentialStoreError.corruptCredential
        }
    }

    func save(_ credential: Credential) throws {
        let data = try JSONEncoder().encode(credential)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updates: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updates as CFDictionary)
            guard updateStatus == errSecSuccess else { throw CredentialStoreError.keychain(updateStatus) }
        } else if status != errSecSuccess {
            throw CredentialStoreError.keychain(status)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

nonisolated enum CredentialStoreError: LocalizedError, Sendable {
    case keychain(OSStatus)
    case corruptCredential

    var errorDescription: String? {
        switch self {
        case .keychain: "QuickInbox could not access its secure credential storage."
        case .corruptCredential: "The saved QuickInbox session was invalid and has been removed."
        }
    }
}
