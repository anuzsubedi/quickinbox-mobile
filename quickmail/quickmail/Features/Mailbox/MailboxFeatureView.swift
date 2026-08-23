import SwiftUI

struct MailboxFeatureView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var model: MailboxViewModel
    @State private var pendingPermanentDeletion: ThreadSummary?

    private let onCompose: (_ draftID: String?) -> Void
    private let onSelectThread: (ThreadSummary) -> Void

    init(
        api: QuickMailAPI,
        onCompose: @escaping (_ draftID: String?) -> Void,
        onSelectThread: @escaping (ThreadSummary) -> Void
    ) {
        _model = State(initialValue: MailboxViewModel(api: api))
        self.onCompose = onCompose
        self.onSelectThread = onSelectThread
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    mailboxSelector
                } detail: {
                    mailboxContent
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack {
                    mailboxContent
                }
            }
        }
        .alert(
            "Couldn't Update Message",
            isPresented: Binding(
                get: { model.actionError != nil },
                set: { if !$0 { model.dismissActionError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.dismissActionError() }
        } message: {
            Text(model.actionError ?? "Please try again.")
        }
        .confirmationDialog(
            "Delete this conversation permanently?",
            isPresented: Binding(
                get: { pendingPermanentDeletion != nil },
                set: { if !$0 { pendingPermanentDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                guard let thread = pendingPermanentDeletion else { return }
                pendingPermanentDeletion = nil
                Task { await model.perform(.delete, on: thread) }
            }
            Button("Cancel", role: .cancel) {
                pendingPermanentDeletion = nil
            }
        } message: {
            Text("This action can't be undone.")
        }
    }

    private var mailboxSelector: some View {
        List(selection: Binding<MailboxKind?>(
            get: { model.selectedMailbox },
            set: { if let mailbox = $0 { model.selectedMailbox = mailbox } }
        )) {
            ForEach(MailboxKind.allCases) { mailbox in
                Label(mailbox.title, systemImage: mailbox.systemImage)
                    .tag(mailbox)
            }
        }
        .navigationTitle("Mailboxes")
    }

    private var mailboxContent: some View {
        contentState
            .navigationTitle(model.selectedMailbox.title)
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $model.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search Messages"
            )
            .toolbar {
                if horizontalSizeClass != .regular {
                    ToolbarItem(placement: .topBarLeading) {
                        mailboxMenu
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    composeButton
                }
            }
            .task {
                if model.currentPage == 0 {
                    await model.reload()
                }
            }
            .task(id: model.searchText) {
                guard model.currentPage > 0 else { return }
                do {
                    try await Task.sleep(for: .milliseconds(350))
                } catch {
                    return
                }
                await model.reload()
            }
            .onChange(of: model.selectedMailbox) {
                model.prepareForMailboxChange()
                Task { await model.reload() }
            }
    }

    @ViewBuilder
    private var contentState: some View {
        if model.isInitialLoading && model.threads.isEmpty {
            ProgressView("Loading \(model.selectedMailbox.title.lowercased())…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = model.initialError, model.threads.isEmpty {
            ErrorStateView(title: "Couldn't Load Mail", message: message) {
                Task { await model.reload() }
            }
        } else if model.threads.isEmpty {
            emptyState
        } else {
            threadList
        }
    }

    private var threadList: some View {
        List(selection: $model.selectedThreadID) {
            ForEach(model.threads) { thread in
                Button {
                    model.selectedThreadID = thread.id
                    if thread.isDraft {
                        onCompose(thread.latestID)
                    } else {
                        onSelectThread(thread)
                    }
                } label: {
                    ThreadSummaryRow(
                        thread: thread,
                        mailbox: model.selectedMailbox,
                        isWorking: model.mutatingThreadIDs.contains(thread.id)
                    )
                }
                .buttonStyle(.plain)
                .tag(thread.id)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    leadingSwipeActions(for: thread)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    trailingSwipeActions(for: thread)
                }
                .contextMenu {
                    contextMenuActions(for: thread)
                }
            }

            if model.hasNextPage {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .task {
                    await model.loadNextPage()
                }
            } else if model.total > model.threads.count {
                Text("\(model.threads.count) of \(model.total)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await model.refresh()
        }
    }

    private var emptyState: some View {
        List {
            ContentUnavailableView {
                Label(
                    model.searchText.isEmpty ? model.selectedMailbox.emptyTitle : "No Results",
                    systemImage: model.searchText.isEmpty ? model.selectedMailbox.systemImage : "magnifyingglass"
                )
            } description: {
                if model.searchText.isEmpty {
                    Text(model.selectedMailbox.emptyDescription)
                } else {
                    Text("No conversations match “\(model.searchText)”.")
                }
            } actions: {
                if !model.searchText.isEmpty {
                    Button("Clear Search") { model.searchText = "" }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .refreshable {
            await model.refresh()
        }
    }

    private var mailboxMenu: some View {
        Menu {
            Picker("Mailbox", selection: $model.selectedMailbox) {
                ForEach(MailboxKind.allCases) { mailbox in
                    Label(mailbox.title, systemImage: mailbox.systemImage)
                        .tag(mailbox)
                }
            }
        } label: {
            Label("Mailboxes", systemImage: "sidebar.left")
        }
        .accessibilityLabel("Choose Mailbox")
    }

    private var composeButton: some View {
        Button {
            onCompose(nil)
        } label: {
            Label("Compose", systemImage: "square.and.pencil")
        }
    }

    @ViewBuilder
    private func leadingSwipeActions(for thread: ThreadSummary) -> some View {
        if model.selectedMailbox != .drafts && model.selectedMailbox != .trash {
            Button {
                Task { await model.perform(thread.isRead ? .unread : .read, on: thread) }
            } label: {
                Label(
                    thread.isRead ? "Mark Unread" : "Mark Read",
                    systemImage: thread.isRead ? "envelope.badge" : "envelope.open"
                )
            }
            .tint(.blue)

            Button {
                Task { await model.perform(thread.isStarred ? .unstar : .star, on: thread) }
            } label: {
                Label(
                    thread.isStarred ? "Unstar" : "Star",
                    systemImage: thread.isStarred ? "star.slash" : "star"
                )
            }
            .tint(.yellow)
        }
    }

    @ViewBuilder
    private func trailingSwipeActions(for thread: ThreadSummary) -> some View {
        switch model.selectedMailbox {
        case .inbox:
            trashButton(for: thread)
            actionButton("Archive", systemImage: "archivebox", tint: .blue) {
                await model.perform(.archive, on: thread)
            }
        case .archive:
            trashButton(for: thread)
            actionButton("Move to Inbox", systemImage: "tray.and.arrow.down", tint: .blue) {
                await model.perform(.unarchive, on: thread)
            }
        case .trash:
            Button(role: .destructive) {
                pendingPermanentDeletion = thread
            } label: {
                Label("Delete", systemImage: "trash.slash")
            }
            actionButton("Restore", systemImage: "arrow.uturn.backward", tint: .blue) {
                await model.perform(.restore, on: thread)
            }
        case .starred, .drafts, .sent:
            trashButton(for: thread)
        }
    }

    @ViewBuilder
    private func contextMenuActions(for thread: ThreadSummary) -> some View {
        if model.selectedMailbox != .drafts && model.selectedMailbox != .trash {
            Button {
                Task { await model.perform(thread.isRead ? .unread : .read, on: thread) }
            } label: {
                Label(
                    thread.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: thread.isRead ? "envelope.badge" : "envelope.open"
                )
            }

            Button {
                Task { await model.perform(thread.isStarred ? .unstar : .star, on: thread) }
            } label: {
                Label(
                    thread.isStarred ? "Remove Star" : "Star",
                    systemImage: thread.isStarred ? "star.slash" : "star"
                )
            }
        }

        if model.selectedMailbox == .trash {
            Button {
                Task { await model.perform(.restore, on: thread) }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            Button("Delete Permanently", systemImage: "trash.slash", role: .destructive) {
                pendingPermanentDeletion = thread
            }
        } else {
            if model.selectedMailbox == .inbox {
                Button {
                    Task { await model.perform(.archive, on: thread) }
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            } else if model.selectedMailbox == .archive {
                Button {
                    Task { await model.perform(.unarchive, on: thread) }
                } label: {
                    Label("Move to Inbox", systemImage: "tray.and.arrow.down")
                }
            }

            Button("Move to Trash", systemImage: "trash", role: .destructive) {
                Task { await model.perform(.trash, on: thread) }
            }
        }
    }

    private func trashButton(for thread: ThreadSummary) -> some View {
        Button(role: .destructive) {
            Task { await model.perform(.trash, on: thread) }
        } label: {
            Label("Trash", systemImage: "trash")
        }
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        action: @escaping @MainActor () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .tint(tint)
    }
}
