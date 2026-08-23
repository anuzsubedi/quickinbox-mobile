import CryptoKit
import Foundation
import SwiftData

@Model
final class CachedMailboxSnapshot {
    @Attribute(.unique) var key: String
    var payload: Data
    var total: Int
    var pageCount: Int
    var updatedAt: Date

    init(key: String, payload: Data, total: Int, pageCount: Int, updatedAt: Date = .now) {
        self.key = key
        self.payload = payload
        self.total = total
        self.pageCount = pageCount
        self.updatedAt = updatedAt
    }
}

nonisolated struct MailboxCacheSnapshot: Sendable {
    let threads: [ThreadSummary]
    let total: Int
    let pageCount: Int
    let updatedAt: Date
}

/// A deliberately small SwiftData cache for the first Inbox page.
///
/// The cache key hashes the server origin and user identifier so account details
/// are not written into the database index. Tokens never enter this store.
@MainActor
final class MailboxCache {
    private let container: ModelContainer?

    init() {
        let schema = Schema([CachedMailboxSnapshot.self])
        let configuration = ModelConfiguration("QuickMailMailboxCache", schema: schema)
        container = try? ModelContainer(for: schema, configurations: [configuration])
    }

    func load(origin: URL, userID: String) -> MailboxCacheSnapshot? {
        guard let container else { return nil }
        let key = Self.key(origin: origin, userID: userID)
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedMailboxSnapshot>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1

        guard let cached = try? context.fetch(descriptor).first,
              let threads = try? APIDateCoding.decoder().decode(
                  [ThreadSummary].self,
                  from: cached.payload
              ) else {
            return nil
        }

        return MailboxCacheSnapshot(
            threads: threads,
            total: cached.total,
            pageCount: max(cached.pageCount, 1),
            updatedAt: cached.updatedAt
        )
    }

    func save(
        threads: [ThreadSummary],
        total: Int,
        pageCount: Int,
        origin: URL,
        userID: String
    ) {
        guard let container,
              let payload = try? APIDateCoding.encoder().encode(threads) else {
            return
        }

        let key = Self.key(origin: origin, userID: userID)
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedMailboxSnapshot>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1

        if let cached = try? context.fetch(descriptor).first {
            cached.payload = payload
            cached.total = total
            cached.pageCount = max(pageCount, 1)
            cached.updatedAt = .now
        } else {
            context.insert(
                CachedMailboxSnapshot(
                    key: key,
                    payload: payload,
                    total: total,
                    pageCount: max(pageCount, 1)
                )
            )
        }
        try? context.save()
    }

    func clearAll() {
        guard let container else { return }
        let context = ModelContext(container)
        guard let snapshots = try? context.fetch(FetchDescriptor<CachedMailboxSnapshot>()) else {
            return
        }
        for snapshot in snapshots {
            context.delete(snapshot)
        }
        try? context.save()
    }

    private nonisolated static func key(origin: URL, userID: String) -> String {
        let identity = Data("\(origin.absoluteString)|\(userID)".utf8)
        return SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
    }
}
