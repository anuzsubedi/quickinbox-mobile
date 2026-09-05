import SwiftUI

struct MailboxFeatureView: View {
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: MailboxViewModel
    @State private var isSelecting = false
    @State private var isScrolled = false
    @State private var expandedHeaderHeight: CGFloat = 100
    @State private var scrollIndicatorMetrics = MailboxScrollIndicatorMetrics()
    @ScaledMetric(relativeTo: .caption) private var indicatorTopInset: CGFloat = 28
    @State private var searchRevealed = false
    @FocusState private var searchFocused: Bool
    private var compactSearch: Bool { !searchRevealed && !searchFocused }
    private var compactHeader: Bool { isScrolled && !selectionActive }
    private var selectionActive: Bool { isSelecting || !selectedThreadIDs.isEmpty }
    @State private var selectedThreadIDs: Set<String> = []
    @State private var pendingPermanentDeletion: [ThreadSummary] = []
    @State private var selectionFeedbackTrigger = 0
    @ScaledMetric(relativeTo: .caption) private var bulkActionMinimum: CGFloat = 72

    private let refreshToken: UUID
    private let needsSignOut: Bool
    private let onSignOut: () -> Void
    private let onOpenSettings: () -> Void
    private let onCompose: (_ draftID: String?) -> Void
    private let onMailboxChanged: () -> Void
    private let onSelectThread: (ThreadSummary) -> Void

    init(
        api: QuickInboxAPI,
        userID: String,
        cache: MailboxCache,
        threadCache: ThreadDetailCache,
        model: MailboxViewModel? = nil,
        refreshToken: UUID = UUID(),
        needsSignOut: Bool = false,
        onSignOut: @escaping () -> Void = {},
        onCompose: @escaping (_ draftID: String?) -> Void,
        onOpenSettings: @escaping () -> Void,
        onMailboxChanged: @escaping () -> Void,
        onSelectThread: @escaping (ThreadSummary) -> Void
    ) {
        _model = State(
            initialValue: model ?? MailboxViewModel(
                api: api,
                userID: userID,
                cache: cache,
                threadCache: threadCache
            )
        )
        self.refreshToken = refreshToken
        self.needsSignOut = needsSignOut
        self.onSignOut = onSignOut
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
                Task {
                    if await model.perform(.delete, on: threads, isBulk: selectionActive || threads.count > 1) {
                        selectedThreadIDs.removeAll()
                        isSelecting = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingPermanentDeletion = []
            }
        } message: {
            Text("You’ll have five seconds to undo before permanent deletion is sent to the server.")
        }
    }

    private var mailboxContent: some View {
        VStack(spacing: 0) {
            if needsSignOut { sessionRevokedBanner.padding(.top, expandedHeaderHeight) }
            else if model.refreshError != nil { cacheStatusBanner.padding(.top, expandedHeaderHeight) }
            contentState
                .contentMargins(.top, model.refreshError == nil && !needsSignOut ? expandedHeaderHeight + 4 : 4, for: .scrollContent)
        }
            .overlay(alignment: .top) { inboxHeader }
            .onPreferenceChange(InboxHeaderHeightKey.self) { height in
                if height > 0, abs(expandedHeaderHeight - height) > 0.5 {
                    expandedHeaderHeight = height
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectionActive || model.undoOffer?.isBulk == true {
                    mailboxDock
                } else {
                    bulkDock
                }
            }
            .background(QuickInboxDesign.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
            .animation(
                QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.stateChange, reduceMotion: reduceMotion),
                value: model.refreshError != nil || needsSignOut
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
            .onChange(of: needsSignOut) { _, revoked in
                guard revoked else { return }
                selectedThreadIDs.removeAll(); isSelecting = false
                pendingPermanentDeletion = []
                model.clearSensitiveState()
            }
            .onChange(of: model.threads.map(\.id)) { _, threadIDs in
                selectedThreadIDs.formIntersection(threadIDs)
            }

    }

    private var inboxHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if selectionActive {
                selectionToolbar(isCompact: false)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if compactHeader {
                            compactMailboxMenu
                                .transition(reduceMotion ? .opacity : .asymmetric(
                                    insertion: .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        } else { mailboxMenu }
                        if !compactHeader {
                            Text(mailboxSummaryDetail)
                                .font(.footnote)
                                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    accountButton
                }
            }
            if !compactHeader && (model.unreadOnly || model.starredOnly) {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text([model.unreadOnly ? "Unread" : nil, model.starredOnly ? "Starred" : nil].compactMap { $0 }.joined(separator: " · "))
                    Spacer()
                    Button("Clear") {
                        model.unreadOnly = false
                        model.starredOnly = false
                        filtersChanged()
                    }
                    .frame(minHeight: 44)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(QuickInboxDesign.Palette.interactiveTint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, compactHeader ? 6 : 10)
        .padding(.bottom, compactHeader ? 8 : 10)
        .background {
            if !compactHeader {
                QuickInboxDesign.Palette.paper.ignoresSafeArea(.container, edges: .top)
            }
        }
        .background {
            if !isScrolled && !selectionActive {
                GeometryReader { proxy in
                    Color.clear.preference(key: InboxHeaderHeightKey.self, value: proxy.size.height)
                }
            }
        }

        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectionActive)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: compactHeader)
    }

    private func selectionToolbar(isCompact: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedThreadIDs.removeAll(); isSelecting = false
                selectionFeedbackTrigger += 1
            } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Clear selection")
            VStack(alignment: .leading, spacing: 3) {
                Text(selectionCountTitle).font(.title2.weight(.semibold))
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button(selectedThreadIDs.count == model.threads.count ? "Deselect All" : "Select All") {
                isSelecting = true
                selectedThreadIDs = selectedThreadIDs.count == model.threads.count ? [] : Set(model.threads.map(\.id))
                selectionFeedbackTrigger += 1
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .accessibilityHint("Applies to loaded conversations")
        }
    }

    private var bulkDock: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: bulkActionMinimum), spacing: 8)], spacing: 8) {
                if model.selectedMailbox == .trash {
                    bulkActionButton("Restore", systemImage: "arrow.uturn.backward", action: .restore)
                } else if model.selectedMailbox != .drafts {
                    bulkActionButton(model.selectedMailbox == .archive ? "Inbox" : "Archive", systemImage: "archivebox", action: model.selectedMailbox == .archive ? .unarchive : .archive)
                }
                if model.selectedMailbox != .drafts {
                    let allRead = selectedThreads.allSatisfy(\.isRead)
                    bulkActionButton(allRead ? "Unread" : "Read", systemImage: allRead ? "envelope.badge" : "envelope.open", action: allRead ? .unread : .read)
                    let allStarred = selectedThreads.allSatisfy(\.isStarred)
                    bulkActionButton(allStarred ? "Unstar" : "Star", systemImage: allStarred ? "star.slash" : "star", action: allStarred ? .unstar : .star)
                }
                if model.selectedMailbox == .trash {
                    Button(role: .destructive) { pendingPermanentDeletion = selectedThreads } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "trash.slash").font(.title3).foregroundStyle(QuickInboxDesign.Palette.destructive)
                            Text("Delete").font(.caption.weight(.semibold)).foregroundStyle(QuickInboxDesign.Palette.destructive)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                    }
                } else {
                    bulkActionButton("Trash", systemImage: "trash", action: .trash, role: .destructive)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .modifier(InboxSolidDock())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .disabled(isBulkWorking || selectedThreads.isEmpty)
    }

    private var selectionCountTitle: String {
        let count = selectedThreadIDs.count
        return count == 1 ? "1 Selected" : "\(count) Selected"
    }

    private var mailboxMenu: some View {
        Menu {
            mailboxPickerOptions
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text(model.selectedMailbox.title)
                    .font(compactHeader ? .title3.weight(.semibold) : .largeTitle.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
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

    private var compactMailboxMenu: some View {
        Menu {
            mailboxPickerOptions
        } label: {
            HStack(spacing: 8) {
                Text(model.selectedMailbox.title)
                    .font(.title3.bold())
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(MailboxCompactMenuGlassStyle())
        .animation(
            QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.selection, reduceMotion: reduceMotion),
            value: model.selectedMailbox
        )
        .menuOrder(.fixed)
        .accessibilityLabel("Mailbox")
        .accessibilityValue(model.selectedMailbox.title)
        .accessibilityHint("Shows all mailboxes")
    }

    @ViewBuilder
    private var mailboxPickerOptions: some View {
        ForEach(MailboxKind.allCases.filter { $0 != .starred }) { mailbox in
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
    }

    private var accountButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                .frame(width: 44, height: 44)
                .modifier(InboxControlSurface(radius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account and settings")
    }

    private func filtersChanged() {
        selectedThreadIDs.removeAll(); isSelecting = false
        selectionFeedbackTrigger += 1
        Task { await model.reload(showInitialLoading: false) }
    }

    private var mailboxDock: some View {
        Group {
            if let offer = model.undoOffer, offer.isBulk || model.inlineUndoThread == nil {
                bulkUndoNotice
                    .padding(5)
                    .modifier(InboxSolidDock())
            } else {
                mailboxDockControls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.undoOffer?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: compactSearch)
    }

    private var mailboxDockControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                if compactSearch {
                    Button { searchRevealed = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.medium))
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search mail")
                    .accessibilityValue(model.searchText.isEmpty ? "No active search" : model.searchText)
                } else {
                    mailboxSearchField.frame(maxWidth: .infinity)
                }
                mailboxFilterMenu
            }
            .padding(4)
            .modifier(InboxControlSurface(radius: 28))

            if compactSearch { Spacer(minLength: 0) }

            Button { onCompose(nil) } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(QuickInboxDesign.Palette.interactiveTint)
                    .frame(width: 58, height: 58)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(InboxControlSurface(radius: 28))
            .accessibilityLabel("Compose")
            .accessibilityHint("Creates a new message")
        }
    }

    private var mailboxFilterMenu: some View {
            Menu {
                Toggle("Unread", isOn: Binding(get: { model.unreadOnly }, set: { model.unreadOnly = $0; filtersChanged() }))
                Toggle("Starred", isOn: Binding(get: { model.starredOnly }, set: { model.starredOnly = $0; filtersChanged() }))
                if model.unreadOnly || model.starredOnly {
                    Button("Clear Filters") {
                        model.unreadOnly = false
                        model.starredOnly = false
                        filtersChanged()
                    }
                }
            } label: {
                Image(systemName: model.unreadOnly || model.starredOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .font(.body.weight(.medium))
                    .foregroundStyle(model.unreadOnly || model.starredOnly ? QuickInboxDesign.Palette.interactiveTint : QuickInboxDesign.Palette.primaryText)
                    .frame(width: 46, height: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter \(model.selectedMailbox.title)")
            .accessibilityValue([model.unreadOnly ? "Unread" : nil, model.starredOnly ? "Starred" : nil].compactMap { $0 }.joined(separator: ", "))

    }

    private var mailboxSearchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityHidden(true)

            TextField("Search mail", text: $model.searchText)
                .focused($searchFocused)
                .task(id: searchRevealed) {
                    if searchRevealed { searchFocused = true }
                }
                .onChange(of: searchFocused) { _, focused in
                    if !focused { searchRevealed = false }
                }
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { searchFocused = false; searchRevealed = false }
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
        .padding(.leading, 15)
        .padding(.trailing, model.searchText.isEmpty ? 15 : 5)
        .frame(minHeight: 50)

    }

    private func selectMailbox(_ mailbox: MailboxKind) {
        guard mailbox != model.selectedMailbox else { return }
        isScrolled = false
        searchRevealed = false
        searchFocused = false
        model.prepareForMailboxChange()
        selectedThreadIDs.removeAll()
        isSelecting = false
        model.selectedMailbox = mailbox
        onMailboxChanged()
        selectionFeedbackTrigger += 1
        Task { await model.reload() }
    }

    @ViewBuilder
    private var contentState: some View {
        if model.isInitialLoading && model.displayedThreads.isEmpty {
            mailboxLoadingState
        } else if let message = model.initialError, model.displayedThreads.isEmpty {
            mailboxErrorState(message)
        } else if model.displayedThreads.isEmpty {
            emptyState
        } else {
            threadList
        }
    }

    private var mailboxLoadingState: some View {
        List {
            ForEach(0..<6, id: \.self) { index in
                MailboxLoadingRow()
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(QuickInboxDesign.Palette.paper)
                    .listRowSeparator(.hidden)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 66 }
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
                Text(section.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .padding(.top, section.id == threadSections.first?.id ? 0 : 12)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(QuickInboxDesign.Palette.paper)
                    .listRowSeparator(.hidden)
                    .accessibilityAddTraits(.isHeader)

                ForEach(section.threads) { thread in
                    if let offer = model.undoOffer, model.inlineUndoThread?.id == thread.id {
                        inlineUndoRow(thread, offer: offer)
                    } else {
                        threadRow(thread, showsBottomSeparator: thread.id != section.threads.last?.id)
                    }
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
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .modifier(MailboxScrollTrackingModifier(isScrolled: $isScrolled, indicatorMetrics: $scrollIndicatorMetrics))
        .modifier(MailboxScrollIndicatorChrome(topInset: expandedHeaderHeight + 4 + indicatorTopInset, metrics: scrollIndicatorMetrics))
        .scrollDismissesKeyboard(.interactively)
        .background(QuickInboxDesign.Palette.paper)
        .refreshable {
            await model.refresh()
        }

    }

    private func inlineUndoRow(_ thread: ThreadSummary, offer: MailboxUndoOffer) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(QuickInboxDesign.Palette.interactiveTint)
                .frame(width: 38, height: 38)
                .background(QuickInboxDesign.Palette.interactiveTint.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(offer.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                Text(thread.subject.isEmpty ? "(No Subject)" : thread.subject)
                    .font(.footnote)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            undoButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 106)
        .background(QuickInboxDesign.Palette.interactiveTint.opacity(0.035))
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(QuickInboxDesign.Palette.paper)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .contain)
    }

    private var undoButton: some View {
        Button { model.undo() } label: {
            Text("Undo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(QuickInboxDesign.Palette.interactiveTint)
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .background(QuickInboxDesign.Palette.interactiveTint.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var bulkUndoNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(QuickInboxDesign.Palette.interactiveTint)
                .accessibilityHidden(true)
            if let offer = model.undoOffer {
                Text(offer.message)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                undoButton
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 3)
        .frame(minHeight: 50)
        .accessibilityElement(children: .contain)
    }

    private func threadRow(_ thread: ThreadSummary, showsBottomSeparator: Bool) -> some View {
        let isWorking = model.mutatingThreadIDs.contains(thread.id)
        let isSelected = selectedThreadIDs.contains(thread.id)

        return Button {
            if selectionActive {
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
                isSelectionActive: selectionActive,
                isSelected: isSelected
            )
        }
        .buttonStyle(MailboxThreadButtonStyle())
        .disabled(isWorking)
        .tag(thread.id)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !selectionActive {
                leadingSwipeActions(for: thread)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !selectionActive {
                trailingSwipeActions(for: thread)
            }
        }
        .contextMenu {
            if !selectionActive {
                contextMenuActions(for: thread)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(!selectionActive ? "Opens conversation" : "Toggles selection")
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(QuickInboxDesign.Palette.paper)
        .listRowSeparator(.hidden, edges: .top)
        .listRowSeparator(showsBottomSeparator ? .visible : .hidden, edges: .bottom)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 66 }
    }

    private func mailboxErrorState(_ message: String) -> some View {
        GeometryReader { proxy in
            ScrollView {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn’t Load \(model.selectedMailbox.title)",
                    message: message,
                    tone: .warning,
                    layout: .embedded,
                    actions: [
                        EmptyStateAction("Try Again", isProminent: true) {
                            Task { await model.reload() }
                        }
                    ]
                )
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(QuickInboxDesign.Palette.paper)
        .refreshable {
            await model.refresh()
        }
    }

    private var emptyState: some View {
        GeometryReader { proxy in
            ScrollView {
                EmptyStateView(
                    systemImage: emptyStateSystemImage,
                    title: emptyStateTitle,
                    message: emptyStateMessage,
                    tone: emptyStateTone,
                    layout: .embedded,
                    actions: emptyStateActions
                )
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(QuickInboxDesign.Palette.paper)
        .refreshable {
            await model.refresh()
        }
    }

    private var emptyStateTitle: String {
        if !model.searchText.isEmpty { return "No Matches" }
        if model.starredOnly { return model.unreadOnly ? "No Unread Starred Mail" : "No Starred Mail" }
        if model.unreadOnly { return "No Unread Mail" }
        return model.selectedMailbox.emptyTitle
    }

    private var emptyStateMessage: String {
        if !model.searchText.isEmpty {
            return "Nothing matched that search. Try another sender, subject, or phrase."
        }
        if model.unreadOnly || model.starredOnly {
            return "No conversations in \(model.selectedMailbox.title) match these filters. Change or clear the filters to see more mail."
        }
        return model.selectedMailbox.emptyDescription
    }

    private var emptyStateSystemImage: String {
        if !model.searchText.isEmpty { return "magnifyingglass" }
        if model.unreadOnly { return "envelope.open.fill" }
        return model.selectedMailbox.emptySystemImage
    }

    private var emptyStateTone: EmptyStateTone {
        model.searchText.isEmpty ? .accent : .muted
    }

    private var emptyStateActions: [EmptyStateAction] {
        if !model.searchText.isEmpty {
            return [
                EmptyStateAction("Clear Search") { model.searchText = "" }
            ]
        }
        if model.unreadOnly || model.starredOnly {
            return [
                EmptyStateAction("Clear Filters") {
                    model.unreadOnly = false
                    model.starredOnly = false
                    filtersChanged()
                }
            ]
        }
        return [
            EmptyStateAction("Check Again") {
                Task { await model.reload() }
            }
        ]
    }

    private var sessionRevokedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Session no longer valid")
                    .font(.subheadline.weight(.semibold))
                Text("This device was signed out on your server.")
                    .font(.caption)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Button("Sign Out", action: onSignOut)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityHint("Removes this session from the device")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(QuickInboxDesign.Palette.paperRaised)
        .overlay(alignment: .bottom) {
            Divider()
        }
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
        for thread in model.displayedThreads {
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
            .tint(QuickInboxDesign.Palette.interactiveTint)

            Button {
                Task { await model.perform(thread.isStarred ? .unstar : .star, on: thread) }
            } label: {
                Label(
                    thread.isStarred ? "Unstar" : "Star",
                    systemImage: thread.isStarred ? "star.slash" : "star"
                )
            }
            .tint(QuickInboxDesign.Palette.starred)
        }
    }

    @ViewBuilder
    private func trailingSwipeActions(for thread: ThreadSummary) -> some View {
        switch model.selectedMailbox {
        case .inbox:
            trashButton(for: thread)
            actionButton("Archive", systemImage: "archivebox", tint: appTheme.palette(for: colorScheme).interactiveTint) {
                await model.perform(.archive, on: thread)
            }
        case .archive:
            trashButton(for: thread)
            actionButton("Move to Inbox", systemImage: "tray.and.arrow.down", tint: appTheme.palette(for: colorScheme).interactiveTint) {
                await model.perform(.unarchive, on: thread)
            }
        case .trash:
            Button(role: .destructive) {
                pendingPermanentDeletion = [thread]
            } label: {
                Label("Delete", systemImage: "trash.slash")
            }
            actionButton("Restore", systemImage: "arrow.uturn.backward", tint: appTheme.palette(for: colorScheme).interactiveTint) {
                await model.perform(.restore, on: thread)
            }
        case .starred, .drafts, .sent:
            trashButton(for: thread)
        }
    }

    @ViewBuilder
    private func contextMenuActions(for thread: ThreadSummary) -> some View {
        Button {
            isSelecting = true
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
        isSelecting = true
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
        Task {
            if await model.perform(action, on: threads) { selectedThreadIDs.removeAll(); isSelecting = false }
        }
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
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 58)

            .contentShape(Rectangle())
        }
        .foregroundStyle(role == .destructive ? AnyShapeStyle(QuickInboxDesign.Palette.destructive) : AnyShapeStyle(QuickInboxDesign.Palette.interactiveTint))
        .accessibilityLabel(title)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(QuickInboxDesign.Palette.fill)
                .frame(width: 36, height: 36)

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
        .padding(.horizontal, 12)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .accessibilityHidden(true)
    }
}

private struct MailboxThreadSection: Identifiable {
    let title: String
    var threads: [ThreadSummary]

    var id: String { title }
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

private struct InboxControlSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat = 28

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .background {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(QuickInboxDesign.Palette.paperGrouped.opacity(0.92))
                        .overlay { RoundedRectangle(cornerRadius: radius).fill(QuickInboxDesign.Palette.interactiveTint.opacity(0.055)) }
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(QuickInboxDesign.Palette.paperRaised)
                        .overlay { RoundedRectangle(cornerRadius: radius).fill(QuickInboxDesign.Palette.interactiveTint.opacity(0.055)) }
                }
                .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(QuickInboxDesign.Palette.separator.opacity(0.4), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
    }
}

private struct InboxSolidDock: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(QuickInboxDesign.Palette.paperRaised, in: RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(QuickInboxDesign.Palette.separator.opacity(0.35), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

private struct MailboxScrollIndicatorMetrics: Equatable {
    var progress: CGFloat = 0
    var thumbRatio: CGFloat = 1
    var isScrollable = false
    var revision: UInt = 0
}

private struct MailboxScrollIndicatorChrome: ViewModifier {
    let topInset: CGFloat
    let metrics: MailboxScrollIndicatorMetrics

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .scrollIndicators(.hidden)
                .overlay(alignment: .topTrailing) {
                    MailboxSlimScrollIndicator(topInset: topInset, metrics: metrics)
                }
        } else {
            content.contentMargins(.top, topInset, for: .scrollIndicators)
        }
    }
}

private struct MailboxSlimScrollIndicator: View {
    let topInset: CGFloat
    let metrics: MailboxScrollIndicatorMetrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var hideTask: Task<Void, Never>?

    private let thumbWidth: CGFloat = 2
    private let minThumbHeight: CGFloat = 16
    private let thumbScale: CGFloat = 0.55

    var body: some View {
        GeometryReader { geometry in
            let trackHeight = max(0, geometry.size.height - topInset)
            let thumbHeight = max(minThumbHeight, trackHeight * metrics.thumbRatio * thumbScale)
            let travel = max(0, trackHeight - thumbHeight)
            let offsetY = topInset + metrics.progress * travel

            Capsule()
                .fill(QuickInboxDesign.Palette.secondaryText.opacity(0.38))
                .frame(width: thumbWidth, height: thumbHeight)
                .offset(x: -3, y: offsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .opacity(isVisible && metrics.isScrollable ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: metrics.revision) {
            revealTemporarily()
        }
        .onChange(of: metrics.isScrollable) { _, isScrollable in
            if !isScrollable {
                hideTask?.cancel()
                isVisible = false
            }
        }
        .onDisappear {
            hideTask?.cancel()
        }
    }

    private func revealTemporarily() {
        guard metrics.isScrollable else {
            isVisible = false
            return
        }

        let showAnimation = QuickInboxDesign.Motion.resolved(
            .easeIn(duration: 0.08),
            reduceMotion: reduceMotion
        )
        let hideAnimation = QuickInboxDesign.Motion.resolved(
            .easeOut(duration: 0.28),
            reduceMotion: reduceMotion
        )

        withAnimation(showAnimation) {
            isVisible = true
        }

        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            withAnimation(hideAnimation) {
                isVisible = false
            }
        }
    }
}

private struct MailboxScrollTrackingModifier: ViewModifier {
    @Binding var isScrolled: Bool
    @Binding var indicatorMetrics: MailboxScrollIndicatorMetrics

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: MailboxScrollSnapshot.self) { geometry in
                let insetHeight = geometry.contentInsets.top + geometry.contentInsets.bottom
                let totalContentHeight = geometry.contentSize.height + insetHeight
                let scrollableOverflow = totalContentHeight - geometry.containerSize.height
                let scrolledDistance = geometry.contentOffset.y + geometry.contentInsets.top
                let isScrollable = scrollableOverflow > 48

                // Don't collapse when the list can't meaningfully scroll.
                let underMasthead: Bool
                if isScrollable {
                    underMasthead = isScrolled ? scrolledDistance > 16 : scrolledDistance > 40
                } else {
                    underMasthead = false
                }

                let thumbRatio = totalContentHeight > 0
                    ? min(1, geometry.containerSize.height / totalContentHeight)
                    : 1
                let progress = scrollableOverflow > 0
                    ? min(1, max(0, scrolledDistance / scrollableOverflow))
                    : 0

                return MailboxScrollSnapshot(
                    isUnderMasthead: underMasthead,
                    metrics: MailboxScrollIndicatorMetrics(
                        progress: progress,
                        thumbRatio: thumbRatio,
                        isScrollable: isScrollable,
                        revision: 0
                    )
                )
            } action: { oldValue, newValue in
                if isScrolled != newValue.isUnderMasthead {
                    isScrolled = newValue.isUnderMasthead
                }

                var metrics = newValue.metrics
                let scrolled =
                    abs(oldValue.metrics.progress - newValue.metrics.progress) > 0.0001
                    || oldValue.metrics.isScrollable != newValue.metrics.isScrollable
                    || abs(oldValue.metrics.thumbRatio - newValue.metrics.thumbRatio) > 0.0001
                if scrolled {
                    metrics.revision = indicatorMetrics.revision &+ 1
                } else {
                    metrics.revision = indicatorMetrics.revision
                }
                if indicatorMetrics != metrics {
                    indicatorMetrics = metrics
                }
            }
        } else {
            content
        }
    }
}

private struct MailboxScrollSnapshot: Equatable {
    var isUnderMasthead: Bool
    var metrics: MailboxScrollIndicatorMetrics
}


private struct InboxHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MailboxCompactMenuGlassStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(QuickInboxDesign.Palette.paperRaised, in: Capsule())
        }
    }
}
