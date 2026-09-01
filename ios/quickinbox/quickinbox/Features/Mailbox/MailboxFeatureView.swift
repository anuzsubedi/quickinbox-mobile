import SwiftUI
import UIKit

struct MailboxFeatureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var model: MailboxViewModel
    @State private var selectedThreadIDs: Set<String> = []
    @State private var pendingPermanentDeletion: [ThreadSummary] = []
    @State private var selectionFeedbackTrigger = 0
    @State private var isContentUnderMasthead = false
    @State private var mastheadHeight: CGFloat = 0
    @State private var scrollIndicatorMetrics = MailboxScrollIndicatorMetrics()

    private let refreshToken: UUID
    private let needsSignOut: Bool
    private let onSignOut: () -> Void
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
        threadCache: ThreadDetailCache,
        refreshToken: UUID = UUID(),
        needsSignOut: Bool = false,
        onSignOut: @escaping () -> Void = {},
        onCompose: @escaping (_ draftID: String?) -> Void,
        onOpenSettings: @escaping () -> Void,
        onMailboxChanged: @escaping () -> Void,
        onSelectThread: @escaping (ThreadSummary) -> Void
    ) {
        _model = State(
            initialValue: MailboxViewModel(
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
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            let reservedMastheadHeight = max(
                mastheadHeight + topInset,
                topInset + (selectedThreadIDs.isEmpty ? 96 : 60)
            )
            let topScrollMargin = model.refreshError == nil && !needsSignOut
                ? reservedMastheadHeight + 12
                : 12
            // Keep the thumb aligned with the first thread row, below the date header.
            let indicatorTopInset = topScrollMargin
                + 4
                + UIFont.preferredFont(forTextStyle: .caption1).lineHeight
                + 4

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    if needsSignOut {
                        sessionRevokedBanner
                            .padding(.top, reservedMastheadHeight)
                            .transition(QuickInboxDesign.Motion.revealTransition(reduceMotion: reduceMotion))
                    } else if model.refreshError != nil {
                        cacheStatusBanner
                            .padding(.top, reservedMastheadHeight)
                            .transition(QuickInboxDesign.Motion.revealTransition(reduceMotion: reduceMotion))
                    }

                    ZStack {
                        contentState
                            .id(contentPhase)
                            .transition(.opacity)
                            .contentMargins(.top, topScrollMargin, for: .scrollContent)
                            .modifier(
                                MailboxScrollIndicatorChrome(
                                    topInset: indicatorTopInset,
                                    metrics: scrollIndicatorMetrics
                                )
                            )
                    }
                    .animation(
                        QuickInboxDesign.Motion.resolved(.easeOut(duration: 0.2), reduceMotion: reduceMotion),
                        value: contentPhase
                    )
                }
                .ignoresSafeArea(.container, edges: .top)

                mailboxChrome
                    .zIndex(1)
            }
            .onPreferenceChange(MailboxMastheadHeightKey.self) { height in
                guard height > 0, abs(mastheadHeight - height) > 0.5 else { return }
                mastheadHeight = height
            }
        }
            .safeAreaInset(edge: .bottom) {
                if selectedThreadIDs.isEmpty {
                    mailboxDock
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
                selectedThreadIDs.removeAll()
                pendingPermanentDeletion = []
                model.clearSensitiveState()
            }
            .onChange(of: model.threads.map(\.id)) { _, threadIDs in
                selectedThreadIDs.formIntersection(threadIDs)
            }
            .onChange(of: contentPhase) { _, phase in
                if phase != .list {
                    isContentUnderMasthead = false
                }
            }
    }

    @ViewBuilder
    private var mailboxMasthead: some View {
        if selectedThreadIDs.isEmpty {
            if isContentUnderMasthead {
                compactMailboxChrome
            } else {
                standardMailboxMasthead
            }
        } else if isContentUnderMasthead {
            compactSelectionChrome
        } else {
            selectionMasthead
        }
    }

    private var mailboxChrome: some View {
        mailboxMasthead
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .modifier(
                MailboxMastheadBackgroundStyle(fillsSafeArea: !isContentUnderMasthead)
            )
            .background {
                // Keep the expanded height while compact chrome is showing so
                // scroll content insets don't jump as the chrome morphs.
                if !isContentUnderMasthead {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: MailboxMastheadHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
            }
            .animation(
                QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.stateChange, reduceMotion: reduceMotion),
                value: isContentUnderMasthead
            )
            .animation(
                QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.stateChange, reduceMotion: reduceMotion),
                value: selectedThreadIDs.isEmpty
            )
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

                if model.isShowingCachedData {
                    Label("Saved", systemImage: "internaldrive")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        .accessibilityLabel("Showing saved mailbox data")
                }

                Spacer(minLength: 8)
            }
            .accessibilityElement(children: .contain)
        }
        .padding(.horizontal, QuickInboxDesign.Layout.horizontalMargin)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .transition(.opacity)
    }

    private var compactMailboxChrome: some View {
        HStack(spacing: 10) {
            compactMailboxMenu
            Spacer(minLength: 4)
            accountButton
        }
        .padding(.horizontal, QuickInboxDesign.Layout.horizontalMargin)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity),
                removal: .opacity
            )
        )
    }

    private var selectionMasthead: some View {
        selectionToolbar(isCompact: false)
            .padding(.horizontal, QuickInboxDesign.Layout.horizontalMargin)
            .padding(.vertical, 6)
            .transition(.opacity)
    }

    private var compactSelectionChrome: some View {
        selectionToolbar(isCompact: true)
            .padding(.horizontal, QuickInboxDesign.Layout.horizontalMargin)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                    removal: .opacity
                )
            )
    }

    private func selectionToolbar(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 8 : 10) {
            selectionDoneButton

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                bulkActionControls
            }
            .modifier(SelectionActionGroupStyle())
        }
        .disabled(isBulkWorking)
        .controlSize(.regular)
    }

    private var selectionDoneButton: some View {
        Button {
            selectedThreadIDs.removeAll()
            selectionFeedbackTrigger += 1
        } label: {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold))
                .frame(width: 34, height: 34)
                .overlay(alignment: .topTrailing) {
                    Text("\(selectedThreadIDs.count)")
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(QuickInboxDesign.Palette.interactiveTint)
                        .padding(.horizontal, selectedThreadIDs.count > 9 ? 4 : 0)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(QuickInboxDesign.Palette.paper, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(QuickInboxDesign.Palette.interactiveTint.opacity(0.35), lineWidth: 1)
                        }
                        .offset(x: 6, y: -6)
                        .contentTransition(.numericText())
                        .accessibilityHidden(true)
                }
        }
        .modifier(SelectionDoneButtonStyle())
        .accessibilityLabel("Done")
        .accessibilityValue(selectionCountTitle)
    }

    private var selectionCountTitle: String {
        let count = selectedThreadIDs.count
        return count == 1 ? "1 Selected" : "\(count) Selected"
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
                    .font(.footnote.weight(.semibold))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Delete Permanently")
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
            Label("More Actions", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.semibold))
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("More Actions")
    }

    private var mailboxMenu: some View {
        Menu {
            mailboxPickerOptions
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
                    .font(.system(size: 11, weight: .bold))
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

    private var mailboxDock: some View {
        HStack(spacing: 10) {
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
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(
                        model.unreadOnly
                            ? QuickInboxDesign.Palette.interactiveTint
                            : QuickInboxDesign.Palette.secondaryText
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .modifier(MailboxDockButtonStyle())
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

            mailboxSearchField
                .frame(maxWidth: .infinity)

            Button {
                onCompose(nil)
            } label: {
                Label("Compose", systemImage: "square.and.pencil")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .modifier(MailboxDockButtonStyle())
            .accessibilityHint("Creates a new message")
        }
        .padding(.horizontal, QuickInboxDesign.Layout.horizontalMargin)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var mailboxSearchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityHidden(true)

            TextField("Search", text: $model.searchText)
                .font(.body)
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
        .padding(.leading, 15)
        .padding(.trailing, model.searchText.isEmpty ? 15 : 5)
        .frame(height: 50)
        .modifier(MailboxSearchGlassStyle())
    }

    private func selectMailbox(_ mailbox: MailboxKind) {
        guard mailbox != model.selectedMailbox else { return }
        model.prepareForMailboxChange()
        isContentUnderMasthead = false
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
            mailboxErrorState(message)
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
            ForEach(0..<6, id: \.self) { index in
                MailboxLoadingRow()
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(index == 5 ? .hidden : .visible, edges: .bottom)
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
                Text(section.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .padding(.top, section.id == threadSections.first?.id ? 0 : 12)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityAddTraits(.isHeader)

                ForEach(section.threads) { thread in
                    threadRow(
                        thread,
                        showsBottomSeparator: thread.id != section.threads.last?.id
                    )
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
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(QuickInboxDesign.Palette.paper)
        .refreshable {
            await model.refresh()
        }
        .modifier(
            MailboxScrollTrackingModifier(
                isScrolled: $isContentUnderMasthead,
                indicatorMetrics: $scrollIndicatorMetrics
            )
        )
    }

    private func threadRow(_ thread: ThreadSummary, showsBottomSeparator: Bool) -> some View {
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
        .listRowSeparator(showsBottomSeparator ? .visible : .hidden, edges: .bottom)
        .listRowSeparatorTint(appTheme.palette(for: colorScheme).separator.opacity(0.58))
        .alignmentGuide(.listRowSeparatorLeading) { _ in 56 }
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
        if model.unreadOnly { return "No Unread Mail" }
        return model.selectedMailbox.emptyTitle
    }

    private var emptyStateMessage: String {
        if !model.searchText.isEmpty {
            return "Nothing matched that search. Try another sender, subject, or phrase."
        }
        if model.unreadOnly {
            return "You’re all caught up — every message here has been read."
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
        if model.unreadOnly {
            return [
                EmptyStateAction("Show All Mail") {
                    model.unreadOnly = false
                    Task { await model.reload(showInitialLoading: false) }
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
                .font(.footnote.weight(.semibold))
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
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

private struct MailboxMastheadHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MailboxSearchGlassStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.interactive(),
                in: .capsule
            )
        } else {
            content
                .background(.thinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(QuickInboxDesign.Palette.separator.opacity(0.55), lineWidth: 0.5)
                }
        }
    }
}

private struct MailboxCompactMenuGlassStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.thinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(QuickInboxDesign.Palette.separator.opacity(0.55), lineWidth: 0.5)
                }
        }
    }
}

private struct MailboxMastheadBackgroundStyle: ViewModifier {
    let fillsSafeArea: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if fillsSafeArea {
            content.background {
                QuickInboxDesign.Palette.paper
                    .ignoresSafeArea(.container, edges: .top)
            }
        } else {
            content
        }
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

private struct SelectionDoneButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(QuickInboxDesign.Palette.interactiveTint)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(QuickInboxDesign.Palette.interactiveTint)
        }
    }
}

private struct SelectionActionGroupStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
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

private struct MailboxDockButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(QuickInboxDesign.Palette.separator.opacity(0.55), lineWidth: 0.5)
                }
        }
    }
}
