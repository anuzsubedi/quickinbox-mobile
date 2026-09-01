import CryptoKit
import Foundation
import OSLog
import SwiftData

@Model
final class CachedMailboxSnapshot {
    @Attribute(.unique) var key: String
    var payload: Data
    var total: Int
    var pageCount: Int
    var currentPage: Int = 1
    var updatedAt: Date

    init(
        key: String,
        payload: Data,
        total: Int,
        pageCount: Int,
        currentPage: Int = 1,
        updatedAt: Date = .now
    ) {
        self.key = key
        self.payload = payload
        self.total = total
        self.pageCount = pageCount
        self.currentPage = currentPage
        self.updatedAt = updatedAt
    }
}

nonisolated struct MailboxCacheSnapshot: Sendable {
    let threads: [ThreadSummary]
    let total: Int
    let pageCount: Int
    let currentPage: Int
    let updatedAt: Date
}

/// A deliberately small SwiftData cache for loaded Inbox pages.
///
/// The cache key hashes the server origin and user identifier so account details
/// are not written into the database index. Tokens never enter this store.
@MainActor
final class MailboxCache {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "QuickInbox",
        category: "MailboxCache"
    )
    private static let lifetime: TimeInterval = 24 * 60 * 60

    private var container: ModelContainer?
    private var didAttemptContainerSetup = false

    init() {}

    func load(origin: URL, userID: String) -> MailboxCacheSnapshot? {
        guard let container = resolvedContainer() else { return nil }
        let key = Self.key(origin: origin, userID: userID)
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedMailboxSnapshot>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1

        let cached: CachedMailboxSnapshot
        do {
            guard let value = try context.fetch(descriptor).first else { return nil }
            cached = value
        } catch {
            Self.logger.error("Failed to load mailbox cache: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let now = Date()
        guard cached.updatedAt <= now,
              now.timeIntervalSince(cached.updatedAt) <= Self.lifetime,
              cached.total >= 0,
              cached.pageCount >= 1,
              cached.currentPage >= 1,
              cached.currentPage <= cached.pageCount,
              let threads = try? APIDateCoding.decoder().decode(
                  [ThreadSummary].self,
                  from: cached.payload
              ),
              !threads.isEmpty else {
            context.delete(cached)
            do {
                try context.save()
                Self.logger.debug("Deleted expired or invalid mailbox cache row")
            } catch {
                context.rollback()
                Self.logger.error("Failed to delete invalid mailbox cache row: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }

        return MailboxCacheSnapshot(
            threads: threads,
            total: cached.total,
            pageCount: cached.pageCount,
            currentPage: cached.currentPage,
            updatedAt: cached.updatedAt
        )
    }

    func save(
        threads: [ThreadSummary],
        total: Int,
        pageCount: Int,
        currentPage: Int,
        origin: URL,
        userID: String
    ) {
        guard let container = resolvedContainer() else {
            return
        }
        let payload: Data
        do {
            payload = try APIDateCoding.encoder().encode(threads)
        } catch {
            Self.logger.error("Failed to encode mailbox cache: \(error.localizedDescription, privacy: .public)")
            return
        }

        let key = Self.key(origin: origin, userID: userID)
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedMailboxSnapshot>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1

        do {
            if let cached = try context.fetch(descriptor).first {
                cached.payload = payload
                cached.total = max(total, 0)
                cached.pageCount = max(pageCount, 1)
                cached.currentPage = min(max(currentPage, 1), max(pageCount, 1))
                cached.updatedAt = .now
            } else {
                context.insert(
                    CachedMailboxSnapshot(
                        key: key,
                        payload: payload,
                        total: max(total, 0),
                        pageCount: max(pageCount, 1),
                        currentPage: min(max(currentPage, 1), max(pageCount, 1))
                    )
                )
            }
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Failed to save mailbox cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearAll() {
        guard let container = resolvedContainer() else { return }
        let context = ModelContext(container)
        do {
            for snapshot in try context.fetch(FetchDescriptor<CachedMailboxSnapshot>()) {
                context.delete(snapshot)
            }
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Failed to clear mailbox cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resolvedContainer() -> ModelContainer? {
        if didAttemptContainerSetup { return container }
        didAttemptContainerSetup = true
        let schema = Schema([CachedMailboxSnapshot.self])
        let configuration = ModelConfiguration("QuickInboxMailboxCache", schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            Self.logger.error("Failed to open mailbox cache: \(error.localizedDescription, privacy: .public)")
        }
        return container
    }

    private nonisolated static func key(origin: URL, userID: String) -> String {
        let identity = Data("\(origin.absoluteString)|\(userID)".utf8)
        return SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
    }
}
