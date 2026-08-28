import SwiftUI

struct MailboxFeatureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var model: MailboxViewModel
    @State private var selectedThreadIDs: Set<String> = []
    @State private var pendingPermanentDeletion: [ThreadSummary] = []
    @State private var selectionFeedbackTrigger = 0

    private let refreshToken: UUID
    private let onOpenSettings: () -> Void
    private let onCompose: (_ draftID: String?) -> Void
    private let onMailboxChanged: () -> Void
    private let onSelectThread: (ThreadSummary) -> Void

    private enum ContentPhase: Hashable {
        case loading
        case error
        case empty
        case list
    }

    init(
        api: QuickInboxAPI,
        userID: String,
        cache: MailboxCache,
        refreshToken: UUID = UUID(),
        onCompose: @escaping (_ draftID: String?) -> Void,
        onOpenSettings: @escaping () -> Void,
        onMailboxChanged: @escaping () -> Void,
        onSelectThread: @escaping (ThreadSummary) -> Void
    ) {
        _model = State(
            initialValue: MailboxViewModel(api: api, userID: userID, cache: cache)
        )
        self.refreshToken = refreshToken
        self.onOpenSettings = onOpenSettings
        self.onCompose = onCompose
        self.onMailboxChanged = onMailboxChanged
        self.onSelectThread = onSelectThread
    }

    var body: some View {
        mailboxContent
        .alert(
            "Couldn’t Update Mail",
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
            permanentDeletionTitle,
            isPresented: Binding(
                get: { !pendingPermanentDeletion.isEmpty },
                set: { if !$0 { pendingPermanentDeletion = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                let threads = pendingPermanentDeletion
                pendingPermanentDeletion = []
                Task { await model.perform(.delete, on: threads) }
            }
            Button("Cancel", role: .cancel) {
                pendingPermanentDeletion = []
            }
        } message: {
            Text("This action can't be undone.")
        }
    }

    private var mailboxContent: some View {
        VStack(spacing: 0) {
            mailboxMasthead

            if model.refreshError != nil {
                cacheStatusBanner
                    .transition(QuickInboxDesign.Motion.revealTransition(reduceMotion: reduceMotion))
            }

            ZStack {
                contentState
                    .id(contentPhase)
                    .transition(.opacity)
            }
            .animation(
                QuickInboxDesign.Motion.resolved(.easeOut(duration: 0.2), reduceMotion: reduceMotion),
                value: contentPhase
            )
        }
            .safeAreaInset(edge: .bottom) {
                if selectedThreadIDs.isEmpty {
                    composeDock
                }
            }
            .background(QuickInboxDesign.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
            .animation(
                QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.stateChange, reduceMotion: reduceMotion),
                value: model.refreshError != nil
            )
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
            .onChange(of: model.threads.map(\.id)) { _, threadIDs in
                selectedThreadIDs.formIntersection(threadIDs)
            }
    }

    @ViewBuilder
    private var mailboxMasthead: some View {
        if selectedThreadIDs.isEmpty {
            standardMailboxMasthead
        } else {
            selectionMasthead
        }
    }

    private var standardMailboxMasthead: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                mailboxMenu
                Spacer(minLength: 4)
                accountButton
            }

            HStack(spacing: 12) {
                Text(mailboxSummaryDetail)
                    .font(.subheadline)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .contentTransition(.numericText())

                Spacer(minLength: 8)

                if model.selectedMailbox == .inbox {
                    Button {
                        model.unreadOnly.toggle()
                        selectionFeedbackTrigger += 1
                        Task { await model.reload(showInitialLoading: false) }
                    } label: {
                        Label(
                            "Unread",
                            systemImage: model.unreadOnly ? "envelope.badge.fill" : "envelope.badge"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .modifier(MailboxFilterButtonStyle(isActive: model.unreadOnly))
                    .controlSize(.small)
                    .frame(minHeight: 44)
                    .accessibilityValue(model.unreadOnly ? "On" : "Off")
                    .accessibilityHint(
                        model.unreadOnly
                            ? "Shows all inbox conversations"
                            : "Shows unread inbox conversations only"
                    )
                    .accessibilityAddTraits(model.unreadOnly ? .isSelected : [])
                    .animation(
                        QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.selection, reduceMotion: reduceMotion),
                        value: model.unreadOnly
                    )
                }
            }
            .accessibilityElement(children: .contain)

            mailboxSearchField
        }
        .padding(.horizontal, QuickInboxDesign.Layout.horizontalMargin)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(QuickInboxDesign.Palette.paper)
    }

    private var selectionMasthead: some View {
        HStack(spacing: 8) {
            Button("Done") {
                selectedThreadIDs.removeAll()
                selectionFeedbackTrigger += 1
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .modifier(SelectionDoneButtonStyle())

            Text("\(selectedThreadIDs.count) Selected")
                .font(.headline)
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 2)

            HStack(spacing: 0) {
                bulkActionControls
            }
            .buttonStyle(.plain)
            .modifier(SelectionActionGroupStyle())
        }
        .disabled(isBulkWorking)
        .padding(.horizontal, QuickInboxDesign.Layout.horizontalMargin)
        .padding(.vertical, 8)
        .background(QuickInboxDesign.Palette.paper)
    }

    @ViewBuilder
    private var bulkActionControls: some View {
        switch model.selectedMailbox {
        case .inbox:
            bulkActionButton("Archive", systemImage: "archivebox", action: .archive)
            bulkActionButton("Move to Trash", systemImage: "trash", action: .trash, role: .destructive)
            bulkMoreMenu
        case .archive:
            bulkActionButton("Move to Inbox", systemImage: "tray.and.arrow.down", action: .unarchive)
            bulkActionButton("Move to Trash", systemImage: "trash", action: .trash, role: .destructive)
            bulkMoreMenu
        case .trash:
            bulkActionButton("Restore", systemImage: "arrow.uturn.backward", action: .restore)
            Button(role: .destructive) {
                pendingPermanentDeletion = selectedThreads
            } label: {
                Label("Delete Permanently", systemImage: "trash.slash")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
            }
        case .drafts:
            bulkActionButton("Move to Trash", systemImage: "trash", action: .trash, role: .destructive)
        case .starred, .sent:
            bulkActionButton("Move to Trash", systemImage: "trash", action: .trash, role: .destructive)
            bulkMoreMenu
        }
    }

    private var bulkMoreMenu: some View {
        Menu {
            Button {
                performBulk(.read)
            } label: {
                Label("Mark as Read", systemImage: "envelope.open")
            }

            Button {
                performBulk(.unread)
            } label: {
                Label("Mark as Unread", systemImage: "envelope.badge")
            }

            Divider()

            Button {
                performBulk(.star)
            } label: {
                Label("Star", systemImage: "star")
            }

            Button {
                performBulk(.unstar)
            } label: {
                Label("Remove Star", systemImage: "star.slash")
            }
        } label: {
            Label("More Actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
        }
        .menuOrder(.fixed)
    }

    private var mailboxMenu: some View {
        Menu {
            ForEach(MailboxKind.allCases) { mailbox in
                Button {
                    selectMailbox(mailbox)
                } label: {
                    Label {
                        HStack {
                            Text(mailbox.title)
                            if mailbox == model.selectedMailbox {
                                Image(systemName: "checkmark")
                            }
                        }
                    } icon: {
                        Image(systemName: mailbox.systemImage)
                    }
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text(model.selectedMailbox.title)
                    .font(.title.bold())
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .frame(width: 18, height: 18, alignment: .center)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(
            QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.selection, reduceMotion: reduceMotion),
            value: model.selectedMailbox
        )
        .menuOrder(.fixed)
        .accessibilityLabel("Mailbox")
        .accessibilityValue(model.selectedMailbox.title)
        .accessibilityHint("Shows all mailboxes")
    }

    private var accountButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.title3.weight(.semibold))
        }
        .modifier(SettingsShortcutStyle())
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Account and settings")
    }

    private var composeDock: some View {
        HStack {
            Spacer()

            FloatingControlGroup {
                FloatingActionButton(
                    "Compose",
                    systemImage: "square.and.pencil"
                ) {
                    onCompose(nil)
                }
                .controlSize(.large)
                .accessibilityHint("Creates a new message")
            }
        }
        .padding(.horizontal, QuickInboxDesign.Spacing.xl)
        .padding(.top, QuickInboxDesign.Spacing.sm)
        .padding(.bottom, 6)
    }

    private var mailboxSearchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
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
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
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
        .modifier(MailboxSearchGlassStyle())
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

    private var contentPhase: ContentPhase {
        if model.isInitialLoading && model.threads.isEmpty { return .loading }
        if model.initialError != nil && model.threads.isEmpty { return .error }
        if model.threads.isEmpty { return .empty }
        return .list
    }

    private var mailboxLoadingState: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                MailboxLoadingRow()
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible, edges: .bottom)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 56 }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(QuickInboxDesign.Palette.paper)
        .allowsHitTesting(false)
        .accessibilityLabel("Loading \(model.selectedMailbox.title.lowercased())")
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        .textCase(nil)
                }
                .listSectionSeparator(.hidden, edges: [.top, .bottom])
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
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(20)
        .listRowSpacing(0)
        .contentMargins(.top, 12, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(QuickInboxDesign.Palette.paper)
        .refreshable {
            await model.refresh()
        }
    }

    private func threadRow(_ thread: ThreadSummary) -> some View {
        let isWorking = model.mutatingThreadIDs.contains(thread.id)
        let isSelected = selectedThreadIDs.contains(thread.id)

        return Button {
            if !selectedThreadIDs.isEmpty {
                toggleSelection(for: thread)
            } else if thread.isDraft {
                onCompose(thread.latestID)
            } else {
                onSelectThread(thread)
            }
        } label: {
            ThreadSummaryRow(
                thread: thread,
                mailbox: model.selectedMailbox,
                isWorking: isWorking,
                isSelectionActive: !selectedThreadIDs.isEmpty,
                isSelected: isSelected
            )
        }
        .buttonStyle(MailboxThreadButtonStyle())
        .disabled(isWorking)
        .tag(thread.id)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if selectedThreadIDs.isEmpty {
                leadingSwipeActions(for: thread)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if selectedThreadIDs.isEmpty {
                trailingSwipeActions(for: thread)
            }
        }
        .contextMenu {
            if selectedThreadIDs.isEmpty {
                contextMenuActions(for: thread)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(selectedThreadIDs.isEmpty ? "Opens conversation" : "Toggles selection")
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden, edges: .top)
        .listRowSeparator(.visible, edges: .bottom)
        .listRowSeparatorTint(appTheme.palette(for: colorScheme).separator.opacity(0.58))
        .alignmentGuide(.listRowSeparatorLeading) { _ in 56 }
    }

    private var emptyState: some View {
        List {
            ContentUnavailableView {
                Label(
                    emptyStateTitle,
                    systemImage: emptyStateSystemImage
                )
            } description: {
                if model.unreadOnly && model.searchText.isEmpty {
                    Text("All messages in your inbox have been read.")
                } else if model.searchText.isEmpty {
                    Text(model.selectedMailbox.emptyDescription)
                } else {
                    Text("Try another sender, subject, or phrase.")
                }
            } actions: {
                if !model.searchText.isEmpty {
                    Button("Clear Search") { model.searchText = "" }
                        .buttonStyle(.bordered)
                } else if model.unreadOnly {
                    Button("Show All Mail") {
                        model.unreadOnly = false
                        Task { await model.reload(showInitialLoading: false) }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Check Again") {
                        Task { await model.reload() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(QuickInboxDesign.Palette.paper)
        .refreshable {
            await model.refresh()
        }
    }

    private var emptyStateTitle: String {
        if model.unreadOnly && model.searchText.isEmpty { return "No Unread Mail" }
        return model.searchText.isEmpty ? model.selectedMailbox.emptyTitle : "No Matches"
    }

    private var emptyStateSystemImage: String {
        if model.unreadOnly && model.searchText.isEmpty { return "envelope.open" }
        return model.searchText.isEmpty ? model.selectedMailbox.systemImage : "magnifyingglass"
    }

    private var cacheStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn’t refresh \(model.selectedMailbox.title)")
                    .font(.subheadline.weight(.semibold))
                if let refreshError = model.refreshError {
                    Text(refreshError)
                        .font(.caption)
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button("Retry") {
                model.dismissRefreshError()
                Task { await model.reload(showInitialLoading: false) }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(QuickInboxDesign.Palette.paperRaised)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var mailboxSummaryDetail: String {
        if model.unreadOnly {
            if !model.searchText.isEmpty {
                return model.total == 1 ? "1 unread result" : "\(model.total) unread results"
            }
            return model.total == 1 ? "1 unread conversation" : "\(model.total) unread conversations"
        }
        if !model.searchText.isEmpty {
            return model.total == 1 ? "1 result" : "\(model.total) results"
        }
        if model.isShowingCachedData {
            return model.total == 1 ? "1 conversation" : "\(model.total) conversations"
        }
        if model.selectedMailbox == .inbox {
            let unread = model.threads.lazy.filter { !$0.isRead }.count
            let unreadLabel = unread == 1 ? "1 unread" : "\(unread) unread"
            if model.total > model.threads.count {
                return "\(unreadLabel) in view · showing \(model.threads.count) of \(model.total)"
            }
            let count = model.total == 1 ? "1 total" : "\(model.total) total"
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
                pendingPermanentDeletion = [thread]
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
        Button {
            selectedThreadIDs = [thread.id]
            selectionFeedbackTrigger += 1
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }

        Divider()

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
                pendingPermanentDeletion = [thread]
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

    private var selectedThreads: [ThreadSummary] {
        model.threads.filter { selectedThreadIDs.contains($0.id) }
    }

    private var isBulkWorking: Bool {
        !model.mutatingThreadIDs.isDisjoint(with: selectedThreadIDs)
    }

    private var permanentDeletionTitle: String {
        if pendingPermanentDeletion.count <= 1 {
            return "Delete this conversation permanently?"
        }
        return "Delete \(pendingPermanentDeletion.count) conversations permanently?"
    }

    private func toggleSelection(for thread: ThreadSummary) {
        if selectedThreadIDs.contains(thread.id) {
            selectedThreadIDs.remove(thread.id)
        } else {
            selectedThreadIDs.insert(thread.id)
        }
        selectionFeedbackTrigger += 1
    }

    private func performBulk(_ action: MailAction) {
        let threads = selectedThreads
        guard !threads.isEmpty else { return }
        Task { await model.perform(action, on: threads) }
    }

    private func bulkActionButton(
        _ title: String,
        systemImage: String,
        action: MailAction,
        role: ButtonRole? = nil
    ) -> some View {
        Button(role: role) {
            performBulk(action)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .foregroundStyle(
                    role == .destructive
                        ? AnyShapeStyle(Color.red)
                        : AnyShapeStyle(QuickInboxDesign.Palette.primaryText)
                )
                .frame(width: 44, height: 44)
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
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(QuickInboxDesign.Palette.fill)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(QuickInboxDesign.Palette.secondaryText.opacity(0.14))
                    .frame(width: 132, height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(QuickInboxDesign.Palette.secondaryText.opacity(0.10))
                    .frame(maxWidth: .infinity)
                    .frame(height: 11)
                RoundedRectangle(cornerRadius: 3)
                    .fill(QuickInboxDesign.Palette.secondaryText.opacity(0.08))
                    .frame(width: 196, height: 11)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .accessibilityHidden(true)
    }
}

private struct MailboxThreadSection: Identifiable {
    let title: String
    var threads: [ThreadSummary]

    var id: String { title }
}

private struct MailboxSearchGlassStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: QuickInboxDesign.Radius.control)
            )
        } else {
            content.background(
                QuickInboxDesign.Palette.fill,
                in: RoundedRectangle(cornerRadius: QuickInboxDesign.Radius.control, style: .continuous)
            )
        }
    }
}

private struct SelectionDoneButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .tint(QuickInboxDesign.Palette.interactiveTint)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private struct SelectionActionGroupStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(.horizontal, 2)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .padding(.horizontal, 2)
                .background(.thinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(QuickInboxDesign.Palette.separator.opacity(0.55), lineWidth: 0.5)
                }
        }
    }
}

private struct MailboxThreadButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        return configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(
                QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.press, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

private struct SettingsShortcutStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

private struct MailboxFilterButtonStyle: ViewModifier {
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme

    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .tint(
                    isActive
                        ? appTheme.palette(for: colorScheme).interactiveTint
                        : appTheme.palette(for: colorScheme).secondaryText
                )
        } else {
            content
                .buttonStyle(.bordered)
                .tint(
                    isActive
                        ? appTheme.palette(for: colorScheme).interactiveTint
                        : appTheme.palette(for: colorScheme).secondaryText
                )
        }
    }
}
