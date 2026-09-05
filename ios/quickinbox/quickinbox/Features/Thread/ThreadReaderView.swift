import SwiftUI

struct ThreadReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var model: ThreadReaderViewModel

    private let api: QuickInboxAPI
    private let refreshToken: UUID
    private let needsSignOut: Bool
    private let onReply: (ThreadMessage, Bool) -> Void
    private let onForward: ([ThreadMessage]) -> Void
    private let onMailboxMutation: () -> Void
    private let onReaderMutation: (MailAction, String) -> Void
    private let onExit: () -> Void

    @State private var downloadingAttachmentID: String?
    @State private var attachmentError: String?
    @State private var previewItem: AttachmentPreviewItem?
    @State private var previewDirectory: URL?
    @State private var pendingDestructiveAction: MailAction?
    @State private var messageExpansion: [String: Bool] = [:]

    init(
        api: QuickInboxAPI,
        userID: String,
        threadID: String,
        summary: ThreadSummary? = nil,
        cache: ThreadDetailCache,
        refreshToken: UUID = UUID(),
        needsSignOut: Bool = false,
        onReply: @escaping (ThreadMessage, Bool) -> Void,
        onForward: @escaping ([ThreadMessage]) -> Void,
        onMailboxMutation: @escaping () -> Void = {},
        onReaderMutation: @escaping (MailAction, String) -> Void = { _, _ in },
        onReaderLoaded: @escaping (ThreadDetail) -> Void = { _ in },
        onExit: @escaping () -> Void = {}
    ) {
        self.api = api
        self.refreshToken = refreshToken
        self.needsSignOut = needsSignOut
        self.onReply = onReply
        self.onForward = onForward
        self.onMailboxMutation = onMailboxMutation
        self.onReaderMutation = onReaderMutation
        self.onExit = onExit
        _model = StateObject(
            wrappedValue: ThreadReaderViewModel(
                api: api,
                userID: userID,
                threadID: threadID,
                summary: summary,
                cache: cache,
                onLoaded: onReaderLoaded
            )
        )
    }

    var body: some View {
        Group {
            if let detail = model.detail {
                VStack(spacing: 0) {
                    if model.refreshError != nil {
                        savedDataBanner
                    }
                    threadContent(detail)
                }
            } else if model.isLoading {
                readerLoadingState
            } else if let error = model.errorMessage {
                ErrorStateView(title: "Conversation Unavailable", message: error) {
                    Task { await model.load() }
                }
            } else {
                Color.clear
            }
        }
        .background(QuickInboxDesign.Palette.paper)
        .animation(
            QuickInboxDesign.Motion.resolved(.easeOut(duration: 0.18), reduceMotion: reduceMotion),
            value: model.detail != nil
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(horizontalSizeClass == .regular)
        .toolbar {
            if horizontalSizeClass == .regular {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: exitReader) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Close conversation")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await perform(model.isStarred ? .unstar : .star) }
                } label: {
                    Image(systemName: model.isStarred ? "star.fill" : "star")
                        .foregroundStyle(model.isStarred ? AnyShapeStyle(QuickInboxDesign.Palette.starred) : AnyShapeStyle(QuickInboxDesign.Palette.primaryText))
                }
                .accessibilityLabel(model.isStarred ? "Unstar conversation" : "Star conversation")
                .disabled(model.detail == nil || model.chronologicalMessages.isEmpty || model.actionInProgress != nil)

                readerActionsMenu
            }
        }
        .task(id: model.threadID) {
            if model.detail == nil { await model.load() }
        }
        .onChange(of: refreshToken) {
            Task { await model.invalidateAndLoad() }
        }
        .onChange(of: needsSignOut) { _, revoked in
            if revoked {
                model.clearSensitiveState()
            }
        }
        .alert("That Change Didn’t Go Through", isPresented: actionErrorPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Your conversation is unchanged. Try again.")
        }
        .alert("Attachment Unavailable", isPresented: attachmentErrorPresented) {
            Button("OK", role: .cancel) { attachmentError = nil }
        } message: {
            Text(attachmentError ?? "Try again.")
        }
        .confirmationDialog(
            destructiveTitle,
            isPresented: destructiveConfirmationPresented,
            titleVisibility: .visible
        ) {
            if let action = pendingDestructiveAction {
                Button(destructiveButtonTitle(action), role: .destructive) {
                    Task { await perform(action, exitsReader: true) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDestructiveAction = nil }
        } message: {
            Text(destructiveMessage)
        }
        .sheet(item: $previewItem, onDismiss: removePreviewFile) { item in
            NavigationStack {
                QuickLookAttachmentPreview(fileURL: item.attachment.fileURL)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(item.attachment.filename)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { previewItem = nil }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            ShareLink(item: item.attachment.fileURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share attachment")
                        }
                    }
            }
        }
        .onDisappear {
            if previewItem != nil { removePreviewFile() }
        }
    }

    private func threadContent(_ detail: ThreadDetail) -> some View {
        let messages = model.chronologicalMessages

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                conversationHeader(detail, messages: messages)

                if messages.isEmpty {
                    EmptyStateView(
                        systemImage: "envelope.open.fill",
                        title: "Conversation Is Empty",
                        message: "Messages in this conversation will appear here.",
                        layout: .embedded
                    )
                } else {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        messageRow(message, isNewest: index == messages.count - 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: QuickInboxDesign.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .background(QuickInboxDesign.Palette.paper)
        }
        .scrollIndicators(.hidden)
        .background(QuickInboxDesign.Palette.paper)
        .refreshable { await model.load() }
        .safeAreaInset(edge: .bottom) {
            if !messages.isEmpty {
                replyDock
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isStarred)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isArchived)
    }

    private func isExpanded(_ message: ThreadMessage) -> Bool {
        model.chronologicalMessages.count == 1 || (messageExpansion[message.id] ?? (message.id == model.chronologicalMessages.last?.id))
    }

    private func setMessageExpansion(_ expands: Bool, messageID: String) {
        guard model.chronologicalMessages.count > 1 else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            messageExpansion[messageID] = expands
        }
    }

    private func messageRow(_ message: ThreadMessage, isNewest: Bool) -> some View {
        let expanded = isExpanded(message)
        return VStack(alignment: .leading, spacing: 0) {
            if model.chronologicalMessages.count > 1 {
                HStack(alignment: .top, spacing: 0) {
                    Button {
                        setMessageExpansion(!expanded, messageID: message.id)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            collapsedMessageLabel(message, isExpanded: expanded)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                                .frame(width: 20, height: 40)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                }
            } else {
                collapsedMessageLabel(message, isExpanded: true)
            }

            if expanded {
                ThreadMessageView(
                    message: message,
                    isNewest: isNewest,
                    showsHeader: false,
                    downloadingAttachmentID: downloadingAttachmentID,
                    openAttachment: download
                )
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(model.chronologicalMessages.count == 1 ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(expanded ? QuickInboxDesign.Palette.paper : QuickInboxDesign.Palette.paperRaised,
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(QuickInboxDesign.Palette.separator.opacity(expanded ? 0.45 : 0.15), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18))
        .contextMenu { individualMessageActions(message) }
        .accessibilityActions { individualMessageActions(message) }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func individualMessageActions(_ message: ThreadMessage) -> some View {
        Button { onForward([message]) } label: {
            Label("Forward", systemImage: "arrowshape.turn.up.right")
        }
        Divider()
        Button {
            UIPasteboard.general.string = EmailAddressPresentation.addressOnly(from: message.fromAddress)
        } label: {
            Label("Copy Sender Address", systemImage: "doc.on.doc")
        }
        if model.chronologicalMessages.count > 1 {
            Button {
                setMessageExpansion(!isExpanded(message), messageID: message.id)
            } label: {
                Label(isExpanded(message) ? "Collapse Email" : "Expand Email", systemImage: isExpanded(message) ? "chevron.up" : "chevron.down")
            }
        }
    }

    // SF Symbols has a double reply arrow; mirror it for double-arrow forwarding.
    private var forwardSymbol: some View {
        Image(systemName: "arrowshape.turn.up.left.2")
            .scaleEffect(x: -1, y: 1)
    }

    private var readerLoadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Opening conversation…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var savedDataBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn’t refresh conversation")
                    .font(.subheadline.weight(.semibold))
                Text(model.isRefreshing ? "Trying again…" : "Showing the last available version. " + (model.refreshError ?? ""))
                    .font(.caption)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if !model.isRefreshing {
                Button("Retry") {
                    Task { await model.load() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(QuickInboxDesign.Palette.paperRaised)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var replyDock: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 8)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    replyButton
                    forwardButton
                    moveButton
                    trashButton
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        replyButton
                        forwardButton
                    }
                    HStack(spacing: 8) {
                        moveButton
                        trashButton
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: QuickInboxDesign.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .background(QuickInboxDesign.Palette.paper)
        .disabled(model.actionInProgress != nil)
    }

    private var replyButton: some View {
        readerDockButton("Reply", symbol: "arrowshape.turn.up.left", emphasized: true) {
            if let latest = model.chronologicalMessages.last { onReply(latest, false) }
        }
    }

    private var forwardButton: some View {
        readerDockButton(model.chronologicalMessages.count > 1 ? "Forward All" : "Forward", symbol: model.chronologicalMessages.count > 1 ? "forward" : "arrowshape.turn.up.right") {
            onForward(model.chronologicalMessages)
        }
        .accessibilityHint("Forwards every email in this conversation")
    }

    private var moveAction: MailAction {
        model.isTrashed ? .restore : (model.isArchived ? .unarchive : .archive)
    }

    private var moveButton: some View {
        readerDockButton(
            model.isTrashed ? "Restore" : (model.isArchived ? "Inbox" : "Archive"),
            symbol: model.isTrashed ? "arrow.uturn.backward" : (model.isArchived ? "tray.and.arrow.down" : "archivebox"),
            pendingAction: moveAction
        ) {
            Task { await perform(moveAction, exitsReader: true) }
        }
        .accessibilityLabel(model.isTrashed ? "Restore conversation" : (model.isArchived ? "Move to Inbox" : "Archive conversation"))
    }

    private var trashButton: some View {
        readerDockButton(
            model.isTrashed ? "Delete" : "Trash",
            symbol: model.isTrashed ? "trash.slash" : "trash",
            pendingAction: model.isTrashed ? .delete : .trash
        ) {
            pendingDestructiveAction = model.isTrashed ? .delete : .trash
        }
        .accessibilityLabel(model.isTrashed ? "Delete permanently" : "Move to Trash")
    }

    private func readerDockButton(
        _ title: String,
        symbol: String,
        emphasized: Bool = false,
        pendingAction: MailAction? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let pendingAction, model.actionInProgress == pendingAction {
                    ProgressView()
                        .frame(height: 22)
                } else {
                    Group {
                        if symbol == "forward" { forwardSymbol }
                        else { Image(systemName: symbol) }
                    }
                    .font(.title3)
                    .frame(height: 22)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(pendingAction == .trash || pendingAction == .delete ? AnyShapeStyle(QuickInboxDesign.Palette.destructive) : AnyShapeStyle(emphasized ? QuickInboxDesign.Palette.interactiveTint : QuickInboxDesign.Palette.primaryText))
            .background {
                if emphasized {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(QuickInboxDesign.Palette.interactiveTint.opacity(0.08))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func conversationHeader(
        _ detail: ThreadDetail,
        messages: [ThreadMessage]
    ) -> some View {
        return VStack(alignment: .leading, spacing: 9) {
            Text(detail.subject.isEmpty ? "(No Subject)" : detail.subject)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)

            if messages.count > 1 {
                HStack(spacing: 6) {
                    Text("\(messages.count) messages")

                    if let latest = messages.last {
                        Text("·")
                            .accessibilityHidden(true)
                        Text(latest.createdAt, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .font(.subheadline)
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private func collapsedMessageLabel(
        _ message: ThreadMessage,
        isExpanded: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ParticipantMonogram(name: collapsedSenderTitle(message), size: 32)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(collapsedSenderTitle(message))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                    .lineLimit(2)

                Text(compactMessageDate(message.createdAt))
                    .font(.caption)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)

                if !isExpanded {
                    Text(messagePreview(message))
                        .font(.subheadline)
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        .lineLimit(2)
                        .padding(.top, 3)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)

            if !message.attachments.isEmpty {
                Image(systemName: "paperclip")
                    .font(.caption)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .padding(.top, 4)
                    .accessibilityLabel("Has attachments")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func collapsedSenderTitle(_ message: ThreadMessage) -> String {
        message.direction == .outbound
            ? "Me"
            : message.senderDisplayName
    }

    private func messagePreview(_ message: ThreadMessage) -> String {
        if let body = message.bodyText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !body.isEmpty {
            return body.replacingOccurrences(of: "\n", with: " ")
        }
        if let html = message.bodyHTML?.trimmingCharacters(in: .whitespacesAndNewlines),
           !html.isEmpty {
            return "Formatted message"
        }
        return "No message content"
    }

    private func compactMessageDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: .now) {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var readerActionsMenu: some View {
        Menu {
            if let latest = model.chronologicalMessages.last {
                Button { onReply(latest, true) } label: {
                    Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
                }
            }
            Button {
                Task { await perform(model.isRead ? .unread : .read) }
            } label: {
                Label(model.isRead ? "Mark as Unread" : "Mark as Read", systemImage: model.isRead ? "envelope.badge" : "envelope.open")
            }
            if model.chronologicalMessages.count > 1 {
                Divider()
                Button {
                    let expand = !model.chronologicalMessages.allSatisfy { isExpanded($0) }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                        for message in model.chronologicalMessages { messageExpansion[message.id] = expand }
                    }
                } label: {
                    Label(model.chronologicalMessages.allSatisfy { isExpanded($0) } ? "Collapse All Messages" : "Expand All Messages", systemImage: "arrow.up.arrow.down")
                }
            }
        } label: {
            Group {
                if model.actionInProgress != nil {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            model.actionInProgress == nil
                ? "More conversation actions"
                : "Updating conversation"
        )
        .disabled(model.detail == nil || model.chronologicalMessages.isEmpty || model.actionInProgress != nil)
    }

    private func perform(_ action: MailAction, exitsReader: Bool = false) async {
        pendingDestructiveAction = nil
        if await model.perform(action) {
            onReaderMutation(action, model.threadID)
            onMailboxMutation()
            if exitsReader {
                exitReader()
            }
        }
    }

    private func exitReader() {
        onExit()
        dismiss()
    }

    private func download(message: ThreadMessage, attachment: EmailAttachment) {
        guard downloadingAttachmentID == nil else { return }
        downloadingAttachmentID = attachment.id
        attachmentError = nil

        Task {
            defer { downloadingAttachmentID = nil }
            do {
                let downloaded = try await api.downloadAttachment(
                    emailID: attachment.emailID ?? message.id,
                    attachment: attachment
                )
                previewDirectory = downloaded.fileURL.deletingLastPathComponent()
                previewItem = AttachmentPreviewItem(attachment: downloaded)
            } catch {
                attachmentError = ThreadReaderViewModel.message(for: error)
            }
        }
    }

    private func removePreviewFile() {
        if let previewDirectory {
            try? FileManager.default.removeItem(at: previewDirectory)
        }
        previewDirectory = nil
        previewItem = nil
    }

    private var actionErrorPresented: Binding<Bool> {
        Binding(
            get: { model.detail != nil && model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var attachmentErrorPresented: Binding<Bool> {
        Binding(
            get: { attachmentError != nil },
            set: { if !$0 { attachmentError = nil } }
        )
    }

    private var destructiveConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDestructiveAction != nil },
            set: { if !$0 { pendingDestructiveAction = nil } }
        )
    }

    private var destructiveTitle: String {
        pendingDestructiveAction == .delete ? "Delete Permanently?" : "Move Conversation to Trash?"
    }

    private var destructiveMessage: String {
        pendingDestructiveAction == .delete
            ? "This conversation and its attachments can’t be recovered."
            : "You can restore this conversation from Trash."
    }

    private func destructiveButtonTitle(_ action: MailAction) -> String {
        action == .delete ? "Delete Permanently" : "Move to Trash"
    }
}
