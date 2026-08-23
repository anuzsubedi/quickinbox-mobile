import SwiftUI

struct MailboxFeatureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var model: MailboxViewModel
    @State private var pendingPermanentDeletion: ThreadSummary?
    @State private var selectionFeedbackTrigger = 0

    private let refreshToken: UUID
    private let accountName: String
    private let onOpenSettings: () -> Void
    private let onCompose: (_ draftID: String?) -> Void
    private let onMailboxChanged: () -> Void
    private let onSelectThread: (ThreadSummary) -> Void

    init(
        api: QuickMailAPI,
        userID: String,
        cache: MailboxCache,
        refreshToken: UUID = UUID(),
        accountName: String,
        onCompose: @escaping (_ draftID: String?) -> Void,
        onOpenSettings: @escaping () -> Void,
        onMailboxChanged: @escaping () -> Void,
        onSelectThread: @escaping (ThreadSummary) -> Void
    ) {
        _model = State(
            initialValue: MailboxViewModel(api: api, userID: userID, cache: cache)
        )
        self.refreshToken = refreshToken
        self.accountName = accountName
        self.onOpenSettings = onOpenSettings
        self.onCompose = onCompose
        self.onMailboxChanged = onMailboxChanged
        self.onSelectThread = onSelectThread
    }

    var body: some View {
        mailboxContent
        .alert(
            "Couldn’t Update Conversation",
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

    private var mailboxContent: some View {
        VStack(spacing: 0) {
            mailboxMasthead

            if model.isShowingCachedData || model.refreshError != nil {
                cacheStatusBanner
            }

            Divider()
            contentState
        }
            .background(QuickMailDesign.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
            .task {
                if model.currentPage == 0 {
                    await model.bootstrap()
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
            .onChange(of: refreshToken) {
                Task { await model.reload(showInitialLoading: false) }
            }
    }

    private var mailboxMasthead: some View {
        VStack(alignment: .leading, spacing: 10) {
            if dynamicTypeSize >= .accessibility1 {
                mailboxMenu
                mastheadActions
            } else {
                HStack(spacing: 10) {
                    mailboxMenu
                    Spacer(minLength: 4)
                    mastheadActions
                }
            }

            Text(mailboxSummaryDetail)
                .font(.subheadline)
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .contentTransition(.numericText())
                .accessibilityElement(children: .combine)

            mailboxSearchField
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(QuickMailDesign.Palette.paper)
    }

    private var mailboxMenu: some View {
        Menu {
            ForEach(MailboxKind.allCases) { mailbox in
                Button {
                    selectMailbox(mailbox)
                } label: {
                    if mailbox == model.selectedMailbox {
                        Label(mailbox.title, systemImage: "checkmark")
                    } else {
                        Label(mailbox.title, systemImage: mailbox.systemImage)
                    }
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(model.selectedMailbox.title)
                    .font(.title.bold())
                    .foregroundStyle(QuickMailDesign.Palette.primaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
        .accessibilityLabel("Mailbox")
        .accessibilityValue(model.selectedMailbox.title)
        .accessibilityHint("Shows all mailboxes")
    }

    private var mastheadActions: some View {
        HStack(spacing: 6) {
            Button {
                onCompose(nil)
            } label: {
                Label("Compose", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(QuickMailDesign.Palette.signalInk, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Creates a new message")

            Button(action: onOpenSettings) {
                ParticipantMonogram(name: accountName, isEmphasized: true, size: 34)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account and settings")
        }
    }

    private var mailboxSearchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .accessibilityHidden(true)

            TextField("Search \(model.selectedMailbox.title)", text: $model.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("Search \(model.selectedMailbox.title)")

            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, model.searchText.isEmpty ? 13 : 4)
        .frame(minHeight: 44)
        .background(QuickMailDesign.Palette.paperRaised, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectMailbox(_ mailbox: MailboxKind) {
        guard mailbox != model.selectedMailbox else { return }
        model.prepareForMailboxChange()
        model.selectedMailbox = mailbox
        onMailboxChanged()
        selectionFeedbackTrigger += 1
        Task { await model.reload() }
    }

    @ViewBuilder
    private var contentState: some View {
        if model.isInitialLoading && model.threads.isEmpty {
            mailboxLoadingState
        } else if let message = model.initialError, model.threads.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t Load \(model.selectedMailbox.title)", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await model.reload() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if model.threads.isEmpty {
            emptyState
        } else {
            threadList
        }
    }

    private var mailboxLoadingState: some View {
        List {
            Section {
                ForEach(0..<6, id: \.self) { _ in
                    MailboxLoadingRow()
                }
            } header: {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .allowsHitTesting(false)
        .overlay {
            ProgressView("Loading \(model.selectedMailbox.title.lowercased())…")
                .accessibilityHidden(false)
        }
    }

    private var threadList: some View {
        List {
            ForEach(threadSections) { section in
                Section {
                    ForEach(section.threads) { thread in
                        threadRow(thread)
                    }
                } header: {
                    Text(section.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .textCase(.uppercase)
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
            } else if shouldShowCaughtUpMarker {
                caughtUpMarker
            } else if model.total > model.threads.count {
                Text("\(model.threads.count) of \(model.total)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.2),
            value: model.threads.map(\.id)
        )
        .refreshable {
            await model.refresh()
        }
    }

    private func threadRow(_ thread: ThreadSummary) -> some View {
        let isWorking = model.mutatingThreadIDs.contains(thread.id)

        return Button {
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
                isWorking: isWorking
            )
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .tag(thread.id)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            leadingSwipeActions(for: thread)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            trailingSwipeActions(for: thread)
        }
        .contextMenu {
            contextMenuActions(for: thread)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private var shouldShowCaughtUpMarker: Bool {
        (1...3).contains(model.threads.count)
            && !model.hasNextPage
            && model.total <= model.threads.count
            && model.searchText.isEmpty
            && !model.isShowingCachedData
            && model.refreshError == nil
    }

    private var caughtUpMarker: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.body.weight(.medium))
                .foregroundStyle(QuickMailDesign.Palette.sage)
                .accessibilityHidden(true)

            Text("All caught up")
                .font(.caption.weight(.medium))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)

            Rectangle()
                .fill(QuickMailDesign.Palette.hairline)
                .frame(height: 0.5)
        }
        .padding(.vertical, 16)
        .listRowInsets(EdgeInsets(top: 0, leading: 66, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        List {
            ContentUnavailableView {
                Label(
                    model.searchText.isEmpty ? model.selectedMailbox.emptyTitle : "No Matches",
                    systemImage: model.searchText.isEmpty ? model.selectedMailbox.systemImage : "magnifyingglass"
                )
            } description: {
                if model.searchText.isEmpty {
                    Text(model.selectedMailbox.emptyDescription)
                } else {
                    Text("Try another sender, subject, or phrase.")
                }
            } actions: {
                if !model.searchText.isEmpty {
                    Button("Clear Search") { model.searchText = "" }
                } else {
                    Button("Check Again") {
                        Task { await model.reload() }
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .refreshable {
            await model.refresh()
        }
    }

    private var cacheStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: model.refreshError == nil ? "clock.arrow.circlepath" : "wifi.slash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    model.refreshError == nil
                        ? "Showing saved mail"
                        : "Couldn’t refresh \(model.selectedMailbox.title)"
                )
                    .font(.subheadline.weight(.semibold))
                if let refreshError = model.refreshError {
                    Text(refreshError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if let cachedAt = model.cachedAt {
                    Text("Updated \(cachedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if model.refreshError != nil {
                Button("Retry") {
                    model.dismissRefreshError()
                    Task { await model.reload(showInitialLoading: false) }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var mailboxSummaryDetail: String {
        if !model.searchText.isEmpty {
            return model.total == 1 ? "1 result" : "\(model.total) results"
        }
        if model.isShowingCachedData, let cachedAt = model.cachedAt {
            let count = model.total == 1 ? "1 conversation" : "\(model.total) conversations"
            return "\(count) · saved \(cachedAt.formatted(.relative(presentation: .named)))"
        }
        if model.selectedMailbox == .inbox {
            let unread = model.threads.lazy.filter { !$0.isRead }.count
            let unreadLabel = unread == 0 ? "All caught up" : (unread == 1 ? "1 unread" : "\(unread) unread")
            if model.total > model.threads.count {
                return "\(unreadLabel) in view · showing \(model.threads.count) of \(model.total)"
            }
            let count = model.total == 1 ? "1 conversation" : "\(model.total) conversations"
            return "\(unreadLabel) · \(count)"
        }
        if model.total > model.threads.count {
            return "Showing \(model.threads.count) of \(model.total)"
        }
        let count = model.total == 1 ? "1 conversation" : "\(model.total) conversations"
        return "\(count) · most recent first"
    }

    private var threadSections: [MailboxThreadSection] {
        var sections: [MailboxThreadSection] = []
        for thread in model.threads {
            let title = sectionTitle(for: thread.createdAt)
            if let index = sections.firstIndex(where: { $0.title == title }) {
                sections[index].threads.append(thread)
            } else {
                sections.append(MailboxThreadSection(title: title, threads: [thread]))
            }
        }
        return sections
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now), date >= weekAgo {
            return "Previous 7 Days"
        }
        if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.wide))
        }
        return date.formatted(.dateTime.year())
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

private struct MailboxLoadingRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.14))
                .frame(width: 150, height: 12)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 11)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.08))
                .frame(width: 220, height: 11)
        }
        .padding(.vertical, 9)
        .accessibilityHidden(true)
    }
}

private struct MailboxThreadSection: Identifiable {
    let title: String
    var threads: [ThreadSummary]

    var id: String { title }
}
