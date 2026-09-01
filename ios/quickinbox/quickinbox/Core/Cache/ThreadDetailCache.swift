import CryptoKit
import Foundation
import OSLog
import SwiftData

@Model
final class CachedThreadDetail {
    @Attribute(.unique) var key: String
    var accountKey: String
    var payload: Data
    var updatedAt: Date
    var lastAccessedAt: Date

    init(
        key: String,
        accountKey: String,
        payload: Data,
        updatedAt: Date = .now,
        lastAccessedAt: Date = .now
    ) {
        self.key = key
        self.accountKey = accountKey
        self.payload = payload
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
    }
}

nonisolated struct ThreadDetailCacheSnapshot: Sendable {
    let detail: ThreadDetail
    let updatedAt: Date
}

/// Stores recent conversation JSON only. Attachment files remain ephemeral.
@MainActor
final class ThreadDetailCache {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "QuickInbox",
        category: "ThreadDetailCache"
    )

    private let lifetime: TimeInterval
    private let accountLimit: Int
    private let now: () -> Date
    private var container: ModelContainer?
    private var didAttemptContainerSetup = false

    init(
        lifetime: TimeInterval = 24 * 60 * 60,
        accountLimit: Int = 64,
        now: @escaping () -> Date = Date.init
    ) {
        self.lifetime = lifetime
        self.accountLimit = max(accountLimit, 1)
        self.now = now
    }

    func load(origin: URL, userID: String, threadID: String) -> ThreadDetailCacheSnapshot? {
        guard let container = resolvedContainer() else { return nil }
        let key = Self.key(origin: origin, userID: userID, threadID: threadID)
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedThreadDetail>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1

        do {
            guard let cached = try context.fetch(descriptor).first else { return nil }
            let currentDate = now()
            guard isValid(cached.updatedAt, now: currentDate),
                  let detail = try? APIDateCoding.decoder().decode(
                      ThreadDetail.self,
                      from: cached.payload
                  ),
                  detail.threadID == threadID else {
                context.delete(cached)
                try context.save()
                Self.logger.debug("Deleted expired or invalid thread cache row")
                return nil
            }

            cached.lastAccessedAt = currentDate
            do {
                try context.save()
            } catch {
                context.rollback()
                Self.logger.error("Failed to update thread cache access time: \(error.localizedDescription, privacy: .public)")
            }
            return ThreadDetailCacheSnapshot(detail: detail, updatedAt: cached.updatedAt)
        } catch {
            Self.logger.error("Failed to load thread cache: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save(_ detail: ThreadDetail, origin: URL, userID: String) {
        guard let container = resolvedContainer() else { return }
        let payload: Data
        do {
            payload = try APIDateCoding.encoder().encode(detail)
        } catch {
            Self.logger.error("Failed to encode thread cache: \(error.localizedDescription, privacy: .public)")
            return
        }

        let accountKey = Self.accountKey(origin: origin, userID: userID)
        let key = Self.key(origin: origin, userID: userID, threadID: detail.threadID)
        let currentDate = now()
        let context = ModelContext(container)
        var existingDescriptor = FetchDescriptor<CachedThreadDetail>(
            predicate: #Predicate { $0.key == key }
        )
        existingDescriptor.fetchLimit = 1

        do {
            if let cached = try context.fetch(existingDescriptor).first {
                cached.payload = payload
                cached.updatedAt = currentDate
                cached.lastAccessedAt = currentDate
            } else {
                context.insert(
                    CachedThreadDetail(
                        key: key,
                        accountKey: accountKey,
                        payload: payload,
                        updatedAt: currentDate,
                        lastAccessedAt: currentDate
                    )
                )
            }

            let accountDescriptor = FetchDescriptor<CachedThreadDetail>(
                predicate: #Predicate { $0.accountKey == accountKey },
                sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
            )
            let accountRows = try context.fetch(accountDescriptor)
            for row in accountRows.dropFirst(accountLimit) {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Failed to save thread cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    func remove(origin: URL, userID: String, threadID: String) {
        guard let container = resolvedContainer() else { return }
        let key = Self.key(origin: origin, userID: userID, threadID: threadID)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedThreadDetail>(
            predicate: #Predicate { $0.key == key }
        )
        do {
            for row in try context.fetch(descriptor) {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Failed to invalidate thread cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearAll() {
        guard let container = resolvedContainer() else { return }
        let context = ModelContext(container)
        do {
            for row in try context.fetch(FetchDescriptor<CachedThreadDetail>()) {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Failed to clear thread cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func isValid(_ timestamp: Date, now currentDate: Date) -> Bool {
        timestamp <= currentDate && currentDate.timeIntervalSince(timestamp) <= lifetime
    }

    private func resolvedContainer() -> ModelContainer? {
        if didAttemptContainerSetup { return container }
        didAttemptContainerSetup = true
        let schema = Schema([CachedThreadDetail.self])
        let configuration = ModelConfiguration("QuickInboxThreadDetailCache", schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            Self.logger.error("Failed to open thread cache: \(error.localizedDescription, privacy: .public)")
        }
        return container
    }

    private nonisolated static func accountKey(origin: URL, userID: String) -> String {
        hash("\(origin.absoluteString)|\(userID)")
    }

    private nonisolated static func key(origin: URL, userID: String, threadID: String) -> String {
        hash("\(origin.absoluteString)|\(userID)|\(threadID)")
    }

    private nonisolated static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
