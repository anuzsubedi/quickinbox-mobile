import SwiftUI

struct ThreadReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var model: ThreadReaderViewModel

    private let api: QuickMailAPI
    private let refreshToken: UUID
    private let onReply: (String) -> Void
    private let onForward: ([ThreadMessage]) -> Void
    private let onMailboxMutation: () -> Void
    private let onExit: () -> Void

    @State private var downloadingAttachmentID: String?
    @State private var attachmentError: String?
    @State private var previewItem: AttachmentPreviewItem?
    @State private var previewDirectory: URL?
    @State private var pendingDestructiveAction: MailAction?
    @State private var expandedMessageID: String?

    init(
        api: QuickMailAPI,
        threadID: String,
        summary: ThreadSummary? = nil,
        refreshToken: UUID = UUID(),
        onReply: @escaping (String) -> Void,
        onForward: @escaping ([ThreadMessage]) -> Void,
        onMailboxMutation: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {}
    ) {
        self.api = api
        self.refreshToken = refreshToken
        self.onReply = onReply
        self.onForward = onForward
        self.onMailboxMutation = onMailboxMutation
        self.onExit = onExit
        _model = StateObject(
            wrappedValue: ThreadReaderViewModel(api: api, threadID: threadID, summary: summary)
        )
    }

    var body: some View {
        Group {
            if let detail = model.detail {
                threadContent(detail)
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
        .background(QuickMailDesign.Palette.paper)
        .navigationTitle(model.chronologicalMessages.count == 1 ? "Message" : "Conversation")
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

            ToolbarItem(placement: .topBarTrailing) {
                readerActionsMenu
            }
        }
        .task(id: model.threadID) {
            if model.detail == nil { await model.load() }
        }
        .onChange(of: refreshToken) {
            Task { await model.load() }
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
            LazyVStack(alignment: .leading, spacing: 10) {
                conversationHeader(detail, messages: messages)

                if messages.isEmpty {
                    ContentUnavailableView {
                        Label("Conversation Is Empty", systemImage: "envelope.open")
                    } description: {
                        Text("Messages in this conversation will appear here.")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 72)
                } else {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if index == messages.count - 1 {
                            ThreadMessageView(
                                message: message,
                                isNewest: true,
                                downloadingAttachmentID: downloadingAttachmentID,
                                openAttachment: download
                            )
                            .padding(.top, messages.count == 1 ? 4 : 12)
                            .padding(.bottom, 28)
                        } else {
                            let isExpanded = expandedMessageID == message.id

                            VStack(alignment: .leading, spacing: 0) {
                                Button {
                                    withAnimation(
                                        reduceMotion ? nil : .easeInOut(duration: 0.2)
                                    ) {
                                        expandedMessageID = isExpanded ? nil : message.id
                                    }
                                } label: {
                                    collapsedMessageLabel(message, isExpanded: isExpanded)
                                }
                                .buttonStyle(.plain)

                                if isExpanded {
                                    ThreadMessageView(
                                        message: message,
                                        isNewest: false,
                                        showsHeader: false,
                                        downloadingAttachmentID: downloadingAttachmentID,
                                        openAttachment: download
                                    )
                                    .padding(.top, 14)
                                    .padding(.leading, 44)
                                    .padding(.bottom, 12)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
            .frame(maxWidth: QuickMailDesign.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .background(QuickMailDesign.Palette.paper)
        }
        .scrollIndicators(.hidden)
        .background(QuickMailDesign.Palette.paper)
        .refreshable { await model.load() }
        .safeAreaInset(edge: .bottom) {
            if !messages.isEmpty {
                replyDock
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isStarred)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isArchived)
    }

    private var readerLoadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Opening conversation…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var replyDock: some View {
        HStack {
            Spacer()

            FloatingControlGroup {
                FloatingActionButton(
                    "Reply",
                    systemImage: "arrowshape.turn.up.left"
                ) {
                    onReply(model.actionTargetID)
                }

                .controlSize(.large)
                .accessibilityHint("Opens a reply to the newest message")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func conversationHeader(
        _ detail: ThreadDetail,
        messages: [ThreadMessage]
    ) -> some View {
        return VStack(alignment: .leading, spacing: 9) {
            Text(detail.subject.isEmpty ? "(No Subject)" : detail.subject)
                .font(.title.weight(.bold))
                .tracking(-0.35)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)

            if !messages.isEmpty {
                HStack(spacing: 6) {
                    Text(messages.count == 1 ? "1 message" : "\(messages.count) messages")

                    if let latest = messages.last {
                        Text("·")
                            .accessibilityHidden(true)
                        Text("Updated \(latest.createdAt, format: .relative(presentation: .named))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, messages.count == 1 ? 10 : 16)
    }

    private func collapsedMessageLabel(
        _ message: ThreadMessage,
        isExpanded: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ParticipantMonogram(
                name: message.direction == .outbound ? "Me" : message.fromAddress,
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(message.direction == .outbound ? "Me" : message.fromAddress)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(compactMessageDate(message.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.direction == .outbound ? "Me" : message.fromAddress)
                            .font(.subheadline.weight(.semibold))
                        Text(compactMessageDate(message.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !isExpanded {
                    Text(messagePreview(message))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if !message.attachments.isEmpty {
                Image(systemName: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Has attachments")
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isExpanded ? "Double-tap to collapse this message" : "Double-tap to expand this message")
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
            if !model.chronologicalMessages.isEmpty {
                Button {
                    if let latestMessage = model.chronologicalMessages.last {
                        onForward([latestMessage])
                    }
                } label: {
                    Label("Forward", systemImage: "arrowshape.turn.up.right")
                }

                if model.chronologicalMessages.count > 1 {
                    Button {
                        onForward(model.chronologicalMessages)
                    } label: {
                        Label("Forward All", systemImage: "arrowshape.turn.up.right")
                    }
                }
            }

            Button {
                Task { await perform(model.isStarred ? .unstar : .star) }
            } label: {
                Label(
                    model.isStarred ? "Unstar" : "Star",
                    systemImage: model.isStarred ? "star.slash" : "star"
                )
            }

            if !model.isTrashed {
                Button {
                    Task {
                        await perform(
                            model.isArchived ? .unarchive : .archive,
                            exitsReader: !model.isArchived
                        )
                    }
                } label: {
                    Label(
                        model.isArchived ? "Move to Inbox" : "Archive",
                        systemImage: model.isArchived ? "tray.and.arrow.down" : "archivebox"
                    )
                }
            }

            Button {
                Task { await perform(model.isRead ? .unread : .read) }
            } label: {
                Label(
                    model.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: model.isRead ? "envelope.badge" : "envelope.open"
                )
            }

            if model.isTrashed {
                Button {
                    Task { await perform(.restore, exitsReader: true) }
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
                Button(role: .destructive) {
                    pendingDestructiveAction = .delete
                } label: {
                    Label("Delete Permanently", systemImage: "trash.slash")
                }
            } else {
                Button(role: .destructive) {
                    pendingDestructiveAction = .trash
                } label: {
                    Label("Move to Trash", systemImage: "trash")
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
        .disabled(model.actionInProgress != nil)
    }

    private func perform(_ action: MailAction, exitsReader: Bool = false) async {
        pendingDestructiveAction = nil
        if await model.perform(action) {
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
