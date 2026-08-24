import Foundation
import Combine

@MainActor
final class ThreadReaderViewModel: ObservableObject {
    @Published private(set) var detail: ThreadDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var actionInProgress: MailAction?
    @Published var errorMessage: String?

    @Published private(set) var isRead: Bool
    @Published private(set) var isStarred: Bool
    @Published private(set) var isArchived: Bool
    @Published private(set) var isTrashed: Bool

    let threadID: String
    private let api: QuickMailAPI

    init(api: QuickMailAPI, threadID: String, summary: ThreadSummary? = nil) {
        self.api = api
        self.threadID = threadID
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
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let value = try await api.thread(id: threadID)
            detail = value
            isRead = value.messages.allSatisfy(\.isRead)
            isStarred = value.messages.contains(where: \.isStarred)
            isArchived = !value.messages.isEmpty && value.messages.allSatisfy { $0.archivedAt != nil }
            isTrashed = !value.messages.isEmpty && value.messages.allSatisfy { $0.deletedAt != nil }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    @discardableResult
    func perform(_ action: MailAction) async -> Bool {
        guard actionInProgress == nil else { return false }
        actionInProgress = action
        errorMessage = nil
        defer { actionInProgress = nil }

        do {
            if action == .delete {
                _ = try await api.deletePermanently(id: actionTargetID)
            } else {
                _ = try await api.perform(action, ids: [actionTargetID])
            }
            apply(action)
            AppFeedback.play(feedbackEvent(for: action))
            return true
        } catch is CancellationError {
            return false
        } catch {
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
}
