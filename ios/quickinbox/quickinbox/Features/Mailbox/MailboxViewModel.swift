import Foundation
import Observation

@MainActor
@Observable
final class MailboxViewModel {
    private let api: any MailboxAPI
    private let cache: MailboxCache
    private let threadCache: ThreadDetailCache
    private let userID: String
    private var requestGeneration = 0
    private var mutationRevision = 0
    private var sessionGeneration = 0
    private var pending: [UUID: PendingMutation] = [:]
    private var undoTask: Task<Void, Never>?
    private var deferredReload = false
    private(set) var undoOffer: MailboxUndoOffer?

    private struct PendingMutation {
        let action: MailAction
        let rows: [ThreadSummary]
        let order: [String]
        let mailbox: MailboxKind
        let query: String
        let unread: Bool
        let starred: Bool
    }

    var selectedMailbox: MailboxKind = .inbox
    var searchText = ""
    var unreadOnly = false
    var starredOnly = false

    private(set) var threads: [ThreadSummary] = []
    private(set) var total = 0
    private(set) var currentPage = 0
    private(set) var pageCount = 1
    // Start loading so the first frame after a fast session restore shows
    // skeletons instead of a false "empty inbox" before .task runs bootstrap.
    private(set) var isInitialLoading = true
    private(set) var isRefreshing = false
    private(set) var isAppending = false
    private(set) var mutatingThreadIDs: Set<String> = []
    private(set) var initialError: String?
    private(set) var cachedAt: Date?
    private(set) var isShowingCachedData = false
    var refreshError: String?
    var actionError: String?

    var inlineUndoThread: ThreadSummary? {
        guard let offer = undoOffer, !offer.isBulk, let mutation = pending[offer.id],
              mutation.mailbox == selectedMailbox, mutation.query == searchText,
              mutation.unread == unreadOnly, mutation.starred == starredOnly else { return nil }
        return mutation.rows.first
    }

    /// Keep a lightweight Undo placeholder in the original row's position.
    var displayedThreads: [ThreadSummary] {
        guard let row = inlineUndoThread, let offer = undoOffer, let mutation = pending[offer.id],
              !threads.contains(where: { $0.id == row.id }) else { return threads }
        var result = threads
        let oldIndex = mutation.order.firstIndex(of: row.id) ?? mutation.order.count
        let next = mutation.order.dropFirst(min(oldIndex + 1, mutation.order.count))
            .compactMap { id in result.firstIndex(where: { $0.id == id }) }.first
        result.insert(row, at: next ?? result.count)
        return result
    }

    var hasNextPage: Bool {
        currentPage > 0 && currentPage < pageCount
    }

    init(
        api: any MailboxAPI,
        userID: String,
        cache: MailboxCache,
        threadCache: ThreadDetailCache
    ) {
        self.api = api
        self.userID = userID
        self.cache = cache
        self.threadCache = threadCache
    }

    func bootstrap() async {
        guard currentPage == 0 else { return }
        isInitialLoading = true
        await restoreCachedInbox()
        if !threads.isEmpty {
            // Cached rows are on screen; keep loading false so pagination isn't blocked
            // while the network refresh completes in the background.
            isInitialLoading = false
            await Task.yield()
        }
        await reload(showInitialLoading: threads.isEmpty)
    }

    func prepareForMailboxChange() {
        requestGeneration += 1
        searchText = ""
        unreadOnly = false
        starredOnly = false
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
        guard pending.isEmpty else { deferredReload = true; return }
        requestGeneration += 1
        let generation = requestGeneration
        let revision = mutationRevision
        defer { if generation == requestGeneration { isInitialLoading = false } }

        if showInitialLoading && threads.isEmpty {
            isInitialLoading = true
        }
        initialError = nil
        refreshError = nil

        do {
            let page = try await api.listThreads(
                mailbox: selectedMailbox,
                page: 1,
                filters: MailboxFilters(query: searchText, unreadOnly: unreadOnly, starredOnly: starredOnly)
            )
            guard generation == requestGeneration else { return }
            guard revision == mutationRevision else {
                await reload(showInitialLoading: false)
                return
            }
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
            guard generation == requestGeneration, revision == mutationRevision else { return }
            if !Self.isUnauthorized(error) {
                if threads.isEmpty {
                    initialError = error.localizedDescription
                } else {
                    refreshError = error.localizedDescription
                }
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
        guard hasNextPage, !isAppending, !isInitialLoading, pending.isEmpty else { return }
        isAppending = true
        defer { isAppending = false }

        let generation = requestGeneration
        let revision = mutationRevision
        let nextPage = currentPage + 1
        do {
            let page = try await api.listThreads(
                mailbox: selectedMailbox,
                page: nextPage,
                filters: MailboxFilters(query: searchText, unreadOnly: unreadOnly, starredOnly: starredOnly)
            )
            guard generation == requestGeneration, revision == mutationRevision else { return }
            threads = merging(threads, with: page.threads)
            total = page.total
            currentPage = page.page
            pageCount = max(page.pageCount, 1)
            await saveInboxCacheIfNeeded()
        } catch is CancellationError {
            return
        } catch {
            guard generation == requestGeneration else { return }
            guard !Self.isUnauthorized(error) else { return }
            actionError = error.localizedDescription
        }
    }

    func perform(_ action: MailAction, on thread: ThreadSummary) async {
        _ = await perform(action, on: [thread], isBulk: false)
    }

    @discardableResult
    func perform(_ action: MailAction, on selectedThreads: [ThreadSummary], isBulk: Bool = true) async -> Bool {
        let rows = Array(Dictionary(selectedThreads.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
        let ids = Set(rows.map(\.id))
        guard !rows.isEmpty, mutatingThreadIDs.isDisjoint(with: ids) else { return false }
        if let previous = undoOffer { commitUndo(previous.id) }
        let id = UUID()
        pending[id] = PendingMutation(action: action, rows: rows, order: threads.map(\.id), mailbox: selectedMailbox,
                                      query: searchText, unread: unreadOnly, starred: starredOnly)
        mutationRevision += 1
        mutatingThreadIDs.formUnion(ids)
        actionError = nil
        for row in rows { apply(action, to: row) }
        AppFeedback.play(feedbackEvent(for: action))
        let offersUndo = isBulk || action == .archive || action == .trash || action == .delete
        if offersUndo && action != .readAll && action != .emptyTrash {
            undoOffer = MailboxUndoOffer(id: id, action: action, count: rows.count, isBulk: isBulk)
            undoTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                self?.commitUndo(id)
            }
        } else {
            Task { await commit(id) }
        }
        return true
    }

    func undo() {
        guard let offer = undoOffer, let mutation = pending.removeValue(forKey: offer.id) else { return }
        undoTask?.cancel()
        undoTask = nil
        undoOffer = nil
        mutationRevision += 1
        mutatingThreadIDs.subtract(mutation.rows.map(\.id))
        rollback(mutation)
        Task { await finishPendingWork() }
    }

    func commitUndo(_ id: UUID) {
        guard undoOffer?.id == id else { return }
        undoTask?.cancel()
        undoTask = nil
        undoOffer = nil
        Task { await commit(id) }
    }

    private func commit(_ id: UUID) async {
        guard let mutation = pending[id] else { return }
        let session = sessionGeneration
        do {
            let response = try await api.perform(mutation.action, ids: mutation.rows.map(\.latestID))
            guard session == sessionGeneration else { return }
            guard response.ok else { throw APIError.invalidResponse }
            await invalidateThreadDetails(Set(mutation.rows.map(\.id)))
        } catch {
            guard session == sessionGeneration else { return }
            rollback(mutation)
            if !Self.isUnauthorized(error) {
                actionError = error.localizedDescription
                AppFeedback.error()
            }
        }
        guard session == sessionGeneration else { return }
        pending.removeValue(forKey: id)
        mutationRevision += 1
        mutatingThreadIDs.subtract(mutation.rows.map(\.id))
        await finishPendingWork()
    }

    private func finishPendingWork() async {
        guard pending.isEmpty else { return }
        await saveInboxCacheIfNeeded()
        if deferredReload {
            deferredReload = false
            await reload(showInitialLoading: false)
        }
    }

    private func rollback(_ mutation: PendingMutation) {
        guard mutation.mailbox == selectedMailbox, mutation.query == searchText,
              mutation.unread == unreadOnly, mutation.starred == starredOnly else {
            deferredReload = true
            return
        }
        for original in mutation.rows.sorted(by: {
            (mutation.order.firstIndex(of: $0.id) ?? 0) < (mutation.order.firstIndex(of: $1.id) ?? 0)
        }) {
            if let index = threads.firstIndex(where: { $0.id == original.id }) {
                threads[index] = original
            } else {
                let oldIndex = mutation.order.firstIndex(of: original.id) ?? mutation.order.count
                let next = mutation.order.dropFirst(min(oldIndex + 1, mutation.order.count))
                    .compactMap { nextID in threads.firstIndex(where: { $0.id == nextID }) }.first
                threads.insert(original, at: next ?? threads.count)
                total += 1
            }
        }
    }

    func receiveReaderMutation(_ action: MailAction, threadID: String) {
        guard !mutatingThreadIDs.contains(threadID) else { return }
        mutationRevision += 1
        if let row = threads.first(where: { $0.id == threadID }) { apply(action, to: row) }
        Task {
            await invalidateThreadDetails([threadID])
            await saveInboxCacheIfNeeded()
        }
    }

    func receiveReaderDetail(_ detail: ThreadDetail) {
        guard !detail.messages.isEmpty, !mutatingThreadIDs.contains(detail.threadID),
              let row = threads.first(where: { $0.id == detail.threadID }) else { return }
        mutationRevision += 1
        let updated = row.updating(isRead: detail.messages.allSatisfy(\.isRead),
                                   isStarred: detail.messages.contains(where: \.isStarred),
                                   isArchived: detail.messages.allSatisfy { $0.archivedAt != nil })
        if (unreadOnly && updated.isRead) || (starredOnly && !updated.isStarred)
            || (selectedMailbox == .inbox && updated.isArchived)
            || (selectedMailbox == .archive && !updated.isArchived)
            || (selectedMailbox != .trash && detail.messages.allSatisfy { $0.deletedAt != nil }) {
            remove(row)
        } else { replace(updated) }
        Task { await saveInboxCacheIfNeeded() }
    }

    func dismissActionError() {
        actionError = nil
    }

    func dismissRefreshError() {
        refreshError = nil
    }

    func clearSensitiveState() {
        sessionGeneration += 1
        undoTask?.cancel()
        undoTask = nil
        undoOffer = nil
        pending.removeAll()
        deferredReload = false
        mutationRevision += 1
        requestGeneration += 1
        threads = []
        total = 0
        currentPage = 0
        pageCount = 1
        isInitialLoading = false
        isRefreshing = false
        isAppending = false
        mutatingThreadIDs = []
        initialError = nil
        cachedAt = nil
        isShowingCachedData = false
        refreshError = nil
        actionError = nil
    }

    private static func isUnauthorized(_ error: Error) -> Bool {
        if let apiError = error as? APIError, apiError == .unauthorized { return true }
        return false
    }

    private func restoreCachedInbox() async {
        let generation = requestGeneration
        let session = sessionGeneration
        guard selectedMailbox == .inbox,
              searchText.isEmpty,
              !unreadOnly,
              !starredOnly,
              let origin = await api.currentCredential?.origin,
              let snapshot = cache.load(origin: origin, userID: userID),
              !snapshot.threads.isEmpty, generation == requestGeneration, session == sessionGeneration else {
            return
        }

        threads = deduplicated(snapshot.threads)
        total = snapshot.total
        currentPage = snapshot.currentPage
        pageCount = snapshot.pageCount
        cachedAt = snapshot.updatedAt
        isShowingCachedData = true
    }

    private func saveInboxCacheIfNeeded() async {
        let generation = requestGeneration
        let revision = mutationRevision
        let session = sessionGeneration
        guard pending.isEmpty, selectedMailbox == .inbox, searchText.isEmpty,
              !unreadOnly, !starredOnly, currentPage >= 1,
              let origin = await api.currentCredential?.origin,
              generation == requestGeneration, revision == mutationRevision, session == sessionGeneration else { return }
        cache.save(threads: threads, total: total, pageCount: pageCount, currentPage: currentPage, origin: origin, userID: userID)
    }

    private func invalidateThreadDetails(_ threadIDs: Set<String>) async {
        guard let origin = await api.currentCredential?.origin else { return }
        for threadID in threadIDs {
            threadCache.remove(origin: origin, userID: userID, threadID: threadID)
        }
    }

    private func apply(_ action: MailAction, to thread: ThreadSummary) {
        switch action {
        case .read:
            if unreadOnly {
                remove(thread)
            } else {
                replace(thread.updating(isRead: true))
            }
        case .unread:
            replace(thread.updating(isRead: false))
        case .star:
            replace(thread.updating(isStarred: true))
        case .unstar:
            if selectedMailbox == .starred || starredOnly {
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
        let count = threads.count
        threads.removeAll { $0.id == thread.id }
        total = max(0, total - (count - threads.count))
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

struct MailboxUndoOffer: Identifiable {
    let id: UUID
    let action: MailAction
    let count: Int
    let isBulk: Bool
    var message: String {
        let subject = count == 1 ? "Conversation" : "\(count) conversations"
        switch action {
        case .archive: return "\(subject) archived"
        case .unarchive: return "\(subject) moved to Inbox"
        case .trash: return "\(subject) moved to Trash"
        case .delete: return "\(subject) deleted"
        case .restore: return "\(subject) restored"
        case .read: return "\(subject) marked read"
        case .unread: return "\(subject) marked unread"
        case .star: return "\(subject) starred"
        case .unstar: return "\(subject) unstarred"
        default: return "\(subject) updated"
        }
    }
}
