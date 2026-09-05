import Foundation
import Testing
@testable import quickinbox

@MainActor
struct MailboxStateTests {
    @Test func undoRestoresOrderWithoutSendingMutation() async {
        let api = StateTestAPI()
        let model = makeModel(api)
        await model.reload()
        let original = model.threads.map(\.id)
        await model.perform(.archive, on: [model.threads[0], model.threads[2]])
        #expect(model.threads.map(\.id) == ["b"])
        #expect(model.total == 1)
        model.undo()
        #expect(model.threads.map(\.id) == original)
        #expect(model.total == 3)
        #expect(model.undoOffer == nil)
        #expect(await api.calls == 0)
    }

    @Test func failedActionRollsBackOnlyItsRows() async {
        let api = StateTestAPI()
        let model = makeModel(api)
        await model.reload()
        let first = model.threads[0]
        let second = model.threads[1]
        await model.perform(.star, on: first)
        model.receiveReaderMutation(.read, threadID: second.id)
        #expect(model.undoOffer == nil)
        for _ in 0..<1000 {
            if model.mutatingThreadIDs.isEmpty { break }
            await Task.yield()
        }
        #expect(!model.threads[0].isStarred)
        #expect(model.threads[1].isRead)
        #expect(model.actionError != nil)
    }

    @Test func individualFlagsSkipUndoButBulkFlagsKeepIt() async {
        for action in [MailAction.read, .unread, .star, .unstar, .restore, .unarchive] {
            let api = StateTestAPI()
            let model = makeModel(api)
            await model.reload()
            await model.perform(action, on: model.threads[0])
            #expect(model.undoOffer == nil)
            for _ in 0..<1000 {
                if model.mutatingThreadIDs.isEmpty { break }
                await Task.yield()
            }
            #expect(await api.calls == 1)
        }
        let model = makeModel(StateTestAPI())
        await model.reload()
        await model.perform(.star, on: [model.threads[0]])
        #expect(model.undoOffer?.isBulk == true)
        model.undo()
    }

    @Test func oldRefreshCannotResurrectArchivedRow() async {
        let api = StateTestAPI()
        let model = makeModel(api)
        await model.reload()
        await api.holdNextPage()
        let request = Task { await model.reload(showInitialLoading: false) }
        for _ in 0..<1000 {
            if await api.isWaiting { break }
            await Task.yield()
        }
        #expect(await api.isWaiting)
        await model.perform(.archive, on: model.threads[0])
        await api.releasePage()
        await request.value
        #expect(model.threads.map(\.id) == ["b", "c"])
        model.undo()
        #expect(model.threads.map(\.id) == ["a", "b", "c"])
    }

    @Test func filtersAreSentTogetherAndReaderUpdatesRespectThem() async {
        let api = StateTestAPI()
        let model = makeModel(api)
        model.unreadOnly = true
        model.starredOnly = true
        await model.reload()
        #expect(await api.lastFilters?.unreadOnly == true)
        #expect(await api.lastFilters?.starredOnly == true)
        model.receiveReaderMutation(.read, threadID: "a")
        model.receiveReaderMutation(.unstar, threadID: "b")
        #expect(model.threads.map(\.id) == ["c"])
    }

    @Test func logoutCancelsUncommittedUndo() async {
        let api = StateTestAPI()
        let model = makeModel(api)
        await model.reload()
        await model.perform(.delete, on: model.threads[0])
        model.clearSensitiveState()
        model.undo()
        #expect(model.threads.isEmpty)
        #expect(model.undoOffer == nil)
        #expect(await api.calls == 0)
    }

    @Test func individualUndoPreservesItsListPosition() async {
        let api = StateTestAPI()
        let model = makeModel(api)
        await model.reload()
        await model.perform(.archive, on: model.threads[1])
        #expect(model.threads.map(\.id) == ["a", "c"])
        #expect(model.displayedThreads.map(\.id) == ["a", "b", "c"])
        #expect(model.inlineUndoThread?.id == "b")
        #expect(model.undoOffer?.isBulk == false)
        model.undo()
        #expect(model.inlineUndoThread == nil)
        #expect(model.threads.map(\.id) == ["a", "b", "c"])
    }

    @Test func oneSelectedEmailStillUsesBulkNotice() async {
        let api = StateTestAPI()
        let model = makeModel(api)
        await model.reload()
        await model.perform(.archive, on: [model.threads[0]])
        #expect(model.inlineUndoThread == nil)
        #expect(model.undoOffer?.isBulk == true)
        model.undo()
    }

    private func makeModel(_ api: StateTestAPI) -> MailboxViewModel {
        MailboxViewModel(api: api, userID: "state-test", cache: MailboxCache(), threadCache: ThreadDetailCache())
    }
}

private actor StateTestAPI: MailboxAPI {
    var currentCredential: Credential? { nil }
    var calls = 0
    var lastFilters: MailboxFilters?
    private var hold = false
    private var continuation: CheckedContinuation<Void, Never>?
    var isWaiting: Bool { continuation != nil }
    func holdNextPage() { hold = true }
    func releasePage() { continuation?.resume(); continuation = nil }

    func listThreads(mailbox: MailboxKind, page: Int, filters: MailboxFilters?) async throws -> MailboxPage {
        lastFilters = filters
        if hold {
            hold = false
            await withCheckedContinuation { continuation = $0 }
        }
        return MailboxPage(threads: ["a", "b", "c"].map { id in
            ThreadSummary(threadID: id, latestID: id, subject: id, preview: "", participants: [], messageCount: 1,
                          isRead: false, isStarred: filters?.starredOnly ?? false, isDraft: false, isArchived: false,
                          hasAttachments: false, domainID: nil, status: nil, createdAt: Date())
        }, total: 3, page: 1, pageCount: 1, pageSize: 20)
    }
    func perform(_ action: MailAction, ids: [String]) async throws -> MailActionResponse {
        calls += 1
        throw URLError(.notConnectedToInternet)
    }
}
