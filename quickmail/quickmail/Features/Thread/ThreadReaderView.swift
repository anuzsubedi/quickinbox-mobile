import SwiftUI

struct ThreadReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: ThreadReaderViewModel

    private let api: QuickMailAPI
    private let refreshToken: UUID
    private let onReply: (String) -> Void
    private let onMailboxMutation: () -> Void
    private let onExit: () -> Void

    @State private var downloadingAttachmentID: String?
    @State private var attachmentError: String?
    @State private var previewItem: AttachmentPreviewItem?
    @State private var previewDirectory: URL?
    @State private var pendingDestructiveAction: MailAction?

    init(
        api: QuickMailAPI,
        threadID: String,
        summary: ThreadSummary? = nil,
        refreshToken: UUID = UUID(),
        onReply: @escaping (String) -> Void,
        onMailboxMutation: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {}
    ) {
        self.api = api
        self.refreshToken = refreshToken
        self.onReply = onReply
        self.onMailboxMutation = onMailboxMutation
        self.onExit = onExit
        _model = StateObject(
            wrappedValue: ThreadReaderViewModel(api: api, threadID: threadID, summary: summary)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            readerMasthead

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
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

    private var readerMasthead: some View {
        ZStack {
            Text("Conversation")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.primaryText)

            HStack(spacing: 8) {
                Button {
                    onExit()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer()

                readerActionsMenu
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(QuickMailDesign.Palette.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QuickMailDesign.Palette.hairline)
                .frame(height: 0.5)
        }
    }

    private func threadContent(_ detail: ThreadDetail) -> some View {
        let messages = model.chronologicalMessages

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
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
                    Divider()

                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if index > 0 {
                            Divider()
                        }

                        if index == messages.count - 1 {
                            ThreadMessageView(
                                message: message,
                                isNewest: true,
                                downloadingAttachmentID: downloadingAttachmentID,
                                openAttachment: download
                            )
                            .padding(.vertical, 24)
                        } else {
                            DisclosureGroup {
                                ThreadMessageView(
                                    message: message,
                                    isNewest: false,
                                    downloadingAttachmentID: downloadingAttachmentID,
                                    openAttachment: download
                                )
                                .padding(.top, 20)
                            } label: {
                                collapsedMessageLabel(message)
                            }
                            .tint(.primary)
                            .padding(.vertical, 17)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
            .frame(maxWidth: QuickMailDesign.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
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
                    systemImage: "arrowshape.turn.up.left",
                    prominence: .prominent
                ) {
                    onReply(model.actionTargetID)
                }
                .tint(QuickMailDesign.Palette.signalInk)
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
        let correspondent = messages.first(where: { $0.direction == .inbound })?.fromAddress
            ?? messages.last?.toAddress
            ?? "Conversation"

        return VStack(alignment: .leading, spacing: 18) {
            Text(detail.subject.isEmpty ? "(No Subject)" : detail.subject)
                .font(.title.weight(.bold))
                .tracking(-0.35)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)

            if !messages.isEmpty {
                HStack(spacing: 12) {
                    ParticipantMonogram(name: correspondent, isEmphasized: true, size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(correspondent)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                            .textSelection(.enabled)

                        HStack(spacing: 6) {
                            Text(messages.count == 1 ? "1 message" : "\(messages.count) messages")

                            if let latest = messages.last {
                                Text("·")
                                    .accessibilityHidden(true)
                                Text("Updated \(latest.createdAt, format: .relative(presentation: .named))")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 30)
        .padding(.bottom, 26)
    }

    private func collapsedMessageLabel(_ message: ThreadMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ParticipantMonogram(
                name: message.direction == .outbound ? "Me" : message.fromAddress,
                size: 36
            )

            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(message.direction == .outbound ? "Me" : message.fromAddress)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(message.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.direction == .outbound ? "Me" : message.fromAddress)
                            .font(.subheadline.weight(.semibold))
                        Text(message.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(messagePreview(message))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !message.attachments.isEmpty {
                Image(systemName: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Has attachments")
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to expand this earlier message")
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

    private var readerActionsMenu: some View {
        Menu {
            Button {
                Task { await perform(model.isStarred ? .unstar : .star) }
            } label: {
                Label(
                    model.isStarred ? "Remove Star" : "Star Conversation",
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
                        model.isArchived ? "Move to Inbox" : "Archive Conversation",
                        systemImage: model.isArchived ? "tray.and.arrow.down" : "archivebox"
                    )
                }
            }

            Divider()

            Button {
                Task { await perform(model.isRead ? .unread : .read) }
            } label: {
                Label(
                    model.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: model.isRead ? "envelope.badge" : "envelope.open"
                )
            }

            Divider()

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
                onExit()
                dismiss()
            }
        }
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
