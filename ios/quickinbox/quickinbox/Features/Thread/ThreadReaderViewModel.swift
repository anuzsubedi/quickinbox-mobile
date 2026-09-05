import Foundation
import Combine

@MainActor
final class ThreadReaderViewModel: ObservableObject {
    @Published private(set) var detail: ThreadDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isShowingCachedData = false
    @Published private(set) var cachedAt: Date?
    @Published private(set) var refreshError: String?
    @Published private(set) var actionInProgress: MailAction?
    @Published var errorMessage: String?

    @Published private(set) var isRead: Bool
    @Published private(set) var isStarred: Bool
    @Published private(set) var isArchived: Bool
    @Published private(set) var isTrashed: Bool

    let threadID: String
    private let api: QuickInboxAPI
    private let userID: String
    private let cache: ThreadDetailCache
    private var didRestoreCache = false
    private var mutationRevision = 0
    private var sessionGeneration = 0
    private let onLoaded: (ThreadDetail) -> Void

    init(
        api: QuickInboxAPI,
        userID: String,
        threadID: String,
        summary: ThreadSummary? = nil,
        cache: ThreadDetailCache,
        onLoaded: @escaping (ThreadDetail) -> Void = { _ in }
    ) {
        self.api = api
        self.userID = userID
        self.threadID = threadID
        self.cache = cache
        self.onLoaded = onLoaded
        isRead = summary?.isRead ?? true
        isStarred = summary?.isStarred ?? false
        isArchived = summary?.isArchived ?? false
        isTrashed = false
    }

    var chronologicalMessages: [ThreadMessage] {
        (detail?.messages ?? []).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var actionTargetID: String {
        chronologicalMessages.last?.id ?? threadID
    }

    func load() async {
        guard !isLoading, !isRefreshing, actionInProgress == nil else { return }
        let session = sessionGeneration
        let revision = mutationRevision
        isLoading = detail == nil
        isRefreshing = detail != nil
        if !didRestoreCache {
            didRestoreCache = true
            await restoreCachedDetail()
        }
        guard session == sessionGeneration else { return }

        isLoading = detail == nil
        isRefreshing = detail != nil
        errorMessage = nil
        // Keep an existing failure visible during Retry; cached content alone is not a failure.
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let value = try await api.thread(id: threadID)
            guard session == sessionGeneration, revision == mutationRevision else { return }
            apply(value)
            refreshError = nil
            isShowingCachedData = false
            cachedAt = nil
            if let origin = await api.currentCredential?.origin {
                guard session == sessionGeneration, revision == mutationRevision else { return }
                cache.save(value, origin: origin, userID: userID)
            }
            guard session == sessionGeneration, revision == mutationRevision else { return }
            onLoaded(value)
        } catch is CancellationError {
            return
        } catch {
            guard session == sessionGeneration, revision == mutationRevision, !Self.isUnauthorized(error) else { return }
            if detail == nil {
                errorMessage = Self.message(for: error)
            } else {
                refreshError = Self.message(for: error)
                isShowingCachedData = true
            }
        }
    }

    func invalidateAndLoad() async {
        await invalidateCache()
        await load()
    }

    @discardableResult
    func perform(_ action: MailAction) async -> Bool {
        guard actionInProgress == nil else { return false }
        actionInProgress = action
        mutationRevision += 1
        let session = sessionGeneration
        errorMessage = nil
        defer { actionInProgress = nil }

        do {
            if action == .delete {
                let response = try await api.deletePermanently(id: actionTargetID)
                guard response.ok else { throw APIError.invalidResponse }
            } else {
                let response = try await api.perform(action, ids: [actionTargetID])
                guard response.ok else { throw APIError.invalidResponse }
            }
            guard session == sessionGeneration else { return false }
            mutationRevision += 1
            apply(action)
            await invalidateCache()
            guard session == sessionGeneration else { return false }
            AppFeedback.play(feedbackEvent(for: action))
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard session == sessionGeneration, !Self.isUnauthorized(error) else { return false }
            errorMessage = Self.message(for: error)
            AppFeedback.error()
            return false
        }
    }

    private func apply(_ action: MailAction) {
        switch action {
        case .read: isRead = true
        case .unread: isRead = false
        case .star: isStarred = true
        case .unstar: isStarred = false
        case .archive:
            isArchived = true
            isTrashed = false
        case .unarchive: isArchived = false
        case .trash:
            isTrashed = true
            isArchived = false
        case .restore: isTrashed = false
        case .delete, .readAll, .emptyTrash: break
        }
    }

    func clearSensitiveState() {
        sessionGeneration += 1
        mutationRevision += 1
        detail = nil
        isLoading = false
        isRefreshing = false
        isShowingCachedData = false
        cachedAt = nil
        refreshError = nil
        errorMessage = nil
        actionInProgress = nil
    }

    private func restoreCachedDetail() async {
        let session = sessionGeneration
        guard let origin = await api.currentCredential?.origin,
              let snapshot = cache.load(origin: origin, userID: userID, threadID: threadID),
              session == sessionGeneration else {
            return
        }
        apply(snapshot.detail, updateFlags: false)
        cachedAt = snapshot.updatedAt
        isShowingCachedData = true
        await Task.yield()
    }

    private func apply(_ value: ThreadDetail, updateFlags: Bool = true) {
        detail = value
        guard updateFlags else { return }
        isRead = value.messages.allSatisfy(\.isRead)
        isStarred = value.messages.contains(where: \.isStarred)
        isArchived = !value.messages.isEmpty && value.messages.allSatisfy { $0.archivedAt != nil }
        isTrashed = !value.messages.isEmpty && value.messages.allSatisfy { $0.deletedAt != nil }
    }

    private func invalidateCache() async {
        guard let origin = await api.currentCredential?.origin else { return }
        cache.remove(origin: origin, userID: userID, threadID: threadID)
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

    static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private static func isUnauthorized(_ error: Error) -> Bool {
        if let apiError = error as? APIError, apiError == .unauthorized { return true }
        return false
    }
}
