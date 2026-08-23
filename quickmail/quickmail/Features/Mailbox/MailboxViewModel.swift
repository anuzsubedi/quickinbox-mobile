import Foundation
import Observation

@MainActor
@Observable
final class MailboxViewModel {
    private let api: QuickMailAPI
    private let cache: MailboxCache
    private let userID: String
    private var requestGeneration = 0

    var selectedMailbox: MailboxKind = .inbox
    var searchText = ""
    var selectedThreadID: String?

    private(set) var threads: [ThreadSummary] = []
    private(set) var total = 0
    private(set) var currentPage = 0
    private(set) var pageCount = 1
    private(set) var isInitialLoading = false
    private(set) var isRefreshing = false
    private(set) var isAppending = false
    private(set) var mutatingThreadIDs: Set<String> = []
    private(set) var initialError: String?
    private(set) var cachedAt: Date?
    private(set) var isShowingCachedData = false
    var refreshError: String?
    var actionError: String?

    var hasNextPage: Bool {
        currentPage > 0 && currentPage < pageCount
    }

    init(api: QuickMailAPI, userID: String, cache: MailboxCache) {
        self.api = api
        self.userID = userID
        self.cache = cache
    }

    func bootstrap() async {
        guard currentPage == 0 else { return }
        await restoreCachedInbox()
        await reload(showInitialLoading: threads.isEmpty)
    }

    func prepareForMailboxChange() {
        requestGeneration += 1
        searchText = ""
        selectedThreadID = nil
        threads = []
        total = 0
        currentPage = 0
        pageCount = 1
        initialError = nil
        cachedAt = nil
        isShowingCachedData = false
        refreshError = nil
        isInitialLoading = true
    }

    func reload(showInitialLoading: Bool = true) async {
        requestGeneration += 1
        let generation = requestGeneration

        if showInitialLoading && threads.isEmpty {
            isInitialLoading = true
        }
        initialError = nil
        refreshError = nil

        do {
            let page = try await api.listThreads(
                mailbox: selectedMailbox,
                page: 1,
                filters: MailboxFilters(query: searchText)
            )
            guard generation == requestGeneration else { return }
            threads = deduplicated(page.threads)
            total = page.total
            currentPage = page.page
            pageCount = max(page.pageCount, 1)
            isShowingCachedData = false
            cachedAt = nil
            await saveInboxCacheIfNeeded()
        } catch is CancellationError {
            return
        } catch {
            guard generation == requestGeneration else { return }
            if threads.isEmpty {
                initialError = error.localizedDescription
            } else {
                refreshError = error.localizedDescription
            }
        }

        guard generation == requestGeneration else { return }
        isInitialLoading = false
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await reload(showInitialLoading: false)
    }

    func loadNextPage() async {
        guard hasNextPage, !isAppending, !isInitialLoading else { return }
        isAppending = true
        defer { isAppending = false }

        let generation = requestGeneration
        let nextPage = currentPage + 1
        do {
            let page = try await api.listThreads(
                mailbox: selectedMailbox,
                page: nextPage,
                filters: MailboxFilters(query: searchText)
            )
            guard generation == requestGeneration else { return }
            threads = merging(threads, with: page.threads)
            total = page.total
            currentPage = page.page
            pageCount = max(page.pageCount, 1)
        } catch is CancellationError {
            return
        } catch {
            guard generation == requestGeneration else { return }
            actionError = error.localizedDescription
        }
    }

    func perform(_ action: MailAction, on thread: ThreadSummary) async {
        guard mutatingThreadIDs.insert(thread.id).inserted else { return }
        defer { mutatingThreadIDs.remove(thread.id) }

        do {
            _ = try await api.perform(action, ids: [thread.latestID])
            apply(action, to: thread)
            await saveInboxCacheIfNeeded()
            AppFeedback.play(feedbackEvent(for: action))
        } catch {
            actionError = error.localizedDescription
            AppFeedback.error()
        }
    }

    func dismissActionError() {
        actionError = nil
    }

    func dismissRefreshError() {
        refreshError = nil
    }

    private func restoreCachedInbox() async {
        guard selectedMailbox == .inbox,
              searchText.isEmpty,
              let origin = await api.currentCredential?.origin,
              let snapshot = cache.load(origin: origin, userID: userID),
              !snapshot.threads.isEmpty else {
            return
        }

        threads = deduplicated(snapshot.threads)
        total = snapshot.total
        currentPage = 1
        pageCount = snapshot.pageCount
        cachedAt = snapshot.updatedAt
        isShowingCachedData = true
    }

    private func saveInboxCacheIfNeeded() async {
        guard selectedMailbox == .inbox,
              searchText.isEmpty,
              currentPage >= 1,
              let origin = await api.currentCredential?.origin else {
            return
        }
        cache.save(
            threads: threads,
            total: total,
            pageCount: pageCount,
            origin: origin,
            userID: userID
        )
    }

    private func apply(_ action: MailAction, to thread: ThreadSummary) {
        switch action {
        case .read:
            replace(thread.updating(isRead: true))
        case .unread:
            replace(thread.updating(isRead: false))
        case .star:
            replace(thread.updating(isStarred: true))
        case .unstar:
            if selectedMailbox == .starred {
                remove(thread)
            } else {
                replace(thread.updating(isStarred: false))
            }
        case .archive:
            if selectedMailbox == .inbox {
                remove(thread)
            } else {
                replace(thread.updating(isArchived: true))
            }
        case .unarchive:
            if selectedMailbox == .archive {
                remove(thread)
            } else {
                replace(thread.updating(isArchived: false))
            }
        case .trash, .restore, .delete:
            remove(thread)
        case .readAll, .emptyTrash:
            break
        }
    }

    private func feedbackEvent(for action: MailAction) -> AppFeedback.Event {
        switch action {
        case .read, .unread, .star, .unstar, .readAll:
            .toggleConfirmed
        case .archive, .unarchive, .restore:
            .moveConfirmed
        case .trash, .delete, .emptyTrash:
            .destructiveConfirmed
        }
    }

    private func replace(_ thread: ThreadSummary) {
        guard let index = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        threads[index] = thread
    }

    private func remove(_ thread: ThreadSummary) {
        threads.removeAll { $0.id == thread.id }
        total = max(0, total - 1)
        if selectedThreadID == thread.id {
            selectedThreadID = nil
        }
    }

    private func deduplicated(_ values: [ThreadSummary]) -> [ThreadSummary] {
        merging([], with: values)
    }

    /// Retains server order while replacing an already-loaded thread with its newest summary.
    private func merging(
        _ existing: [ThreadSummary],
        with incoming: [ThreadSummary]
    ) -> [ThreadSummary] {
        var result = existing
        var indices = Dictionary(uniqueKeysWithValues: existing.enumerated().map { ($1.id, $0) })

        for thread in incoming {
            if let index = indices[thread.id] {
                result[index] = thread
            } else {
                indices[thread.id] = result.count
                result.append(thread)
            }
        }
        return result
    }
}

private extension ThreadSummary {
    func updating(
        isRead: Bool? = nil,
        isStarred: Bool? = nil,
        isArchived: Bool? = nil
    ) -> ThreadSummary {
        ThreadSummary(
            threadID: threadID,
            latestID: latestID,
            subject: subject,
            preview: preview,
            participants: participants,
            messageCount: messageCount,
            isRead: isRead ?? self.isRead,
            isStarred: isStarred ?? self.isStarred,
            isDraft: isDraft,
            isArchived: isArchived ?? self.isArchived,
            hasAttachments: hasAttachments,
            domainID: domainID,
            status: status,
            createdAt: createdAt
        )
    }
}
