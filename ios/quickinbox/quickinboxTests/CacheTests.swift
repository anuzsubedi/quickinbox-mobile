import Foundation
import Testing
@testable import quickinbox

@MainActor
struct CacheTests {
    @Test
    func mailboxRoundTripPreservesPaginationAndAccountIsolation() {
        let cache = MailboxCache()
        cache.clearAll()
        let origin = URL(string: "https://cache-test-\(UUID().uuidString).example")!
        let thread = summary(id: "thread-1")

        cache.save(
            threads: [thread],
            total: 42,
            pageCount: 5,
            currentPage: 3,
            origin: origin,
            userID: "user-a"
        )

        let restored = cache.load(origin: origin, userID: "user-a")
        #expect(restored?.threads == [thread])
        #expect(restored?.total == 42)
        #expect(restored?.pageCount == 5)
        #expect(restored?.currentPage == 3)
        #expect(cache.load(origin: origin, userID: "user-b") == nil)
        cache.clearAll()
    }

    @Test
    func threadRoundTripIsAccountScoped() {
        let cache = ThreadDetailCache()
        cache.clearAll()
        let origin = URL(string: "https://thread-test-\(UUID().uuidString).example")!
        let detail = threadDetail(id: "thread-1")

        cache.save(detail, origin: origin, userID: "user-a")

        #expect(cache.load(origin: origin, userID: "user-a", threadID: detail.threadID)?.detail == detail)
        #expect(cache.load(origin: origin, userID: "user-b", threadID: detail.threadID) == nil)
        #expect(cache.load(origin: origin, userID: "user-a", threadID: "thread-2") == nil)
        cache.clearAll()
    }

    @Test
    func threadCacheExpiresEntriesAtLifetimeBoundary() {
        let storedAt = Date(timeIntervalSince1970: 10_000)
        var currentDate = storedAt
        let cache = ThreadDetailCache(lifetime: 60, now: { currentDate })
        cache.clearAll()
        let origin = URL(string: "https://expiry-test-\(UUID().uuidString).example")!
        let detail = threadDetail(id: "expiring-thread")
        cache.save(detail, origin: origin, userID: "user")

        currentDate = storedAt.addingTimeInterval(60)
        #expect(cache.load(origin: origin, userID: "user", threadID: detail.threadID) != nil)

        currentDate = storedAt.addingTimeInterval(61)
        #expect(cache.load(origin: origin, userID: "user", threadID: detail.threadID) == nil)
        cache.clearAll()
    }

    @Test
    func threadCacheEvictsLeastRecentlyUsedEntry() {
        var currentDate = Date(timeIntervalSince1970: 20_000)
        let cache = ThreadDetailCache(accountLimit: 2, now: { currentDate })
        cache.clearAll()
        let origin = URL(string: "https://lru-test-\(UUID().uuidString).example")!

        for index in 1...3 {
            cache.save(threadDetail(id: "thread-\(index)"), origin: origin, userID: "user")
            currentDate.addTimeInterval(1)
        }

        #expect(cache.load(origin: origin, userID: "user", threadID: "thread-1") == nil)
        #expect(cache.load(origin: origin, userID: "user", threadID: "thread-2") != nil)
        #expect(cache.load(origin: origin, userID: "user", threadID: "thread-3") != nil)
        cache.clearAll()
    }

    private func summary(id: String) -> ThreadSummary {
        ThreadSummary(
            threadID: id,
            latestID: "\(id)-message",
            subject: "Subject",
            preview: "Preview",
            participants: [],
            messageCount: 1,
            isRead: false,
            isStarred: false,
            isDraft: false,
            isArchived: false,
            hasAttachments: false,
            domainID: nil,
            status: nil,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func threadDetail(id: String) -> ThreadDetail {
        ThreadDetail(threadID: id, subject: "Subject", messages: [])
    }
}
