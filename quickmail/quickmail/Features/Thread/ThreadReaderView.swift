import SwiftUI

struct ThreadReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ThreadReaderViewModel

    private let api: QuickMailAPI
    private let onReply: (String) -> Void
    private let onMailboxMutation: () -> Void

    @State private var downloadingAttachmentID: String?
    @State private var attachmentError: String?
    @State private var previewItem: AttachmentPreviewItem?
    @State private var previewDirectory: URL?
    @State private var pendingDestructiveAction: MailAction?

    init(
        api: QuickMailAPI,
        threadID: String,
        summary: ThreadSummary? = nil,
        onReply: @escaping (String) -> Void,
        onMailboxMutation: @escaping () -> Void = {}
    ) {
        self.api = api
        self.onReply = onReply
        self.onMailboxMutation = onMailboxMutation
        _model = StateObject(
            wrappedValue: ThreadReaderViewModel(api: api, threadID: threadID, summary: summary)
        )
    }

    var body: some View {
        Group {
            if let detail = model.detail {
                threadContent(detail)
            } else if model.isLoading {
                ProgressView("Loading conversation…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage {
                ErrorStateView(title: "Couldn’t Load Conversation", message: error) {
                    Task { await model.load() }
                }
            } else {
                Color.clear
            }
        }
        .navigationTitle(model.detail?.subject ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { readerToolbar }
        .task(id: model.threadID) {
            if model.detail == nil { await model.load() }
        }
        .alert("Couldn’t Complete Action", isPresented: actionErrorPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Try again.")
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let messages = model.chronologicalMessages
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    if index == messages.count - 1 {
                        ThreadMessageView(
                            message: message,
                            isNewest: true,
                            downloadingAttachmentID: downloadingAttachmentID,
                            openAttachment: download
                        )
                        .padding(.horizontal)
                        .accessibilityLabel("Newest message")
                    } else {
                        DisclosureGroup {
                            ThreadMessageView(
                                message: message,
                                isNewest: false,
                                downloadingAttachmentID: downloadingAttachmentID,
                                openAttachment: download
                            )
                            .padding(.top, 8)
                        } label: {
                            collapsedMessageLabel(message)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }

                    if index < messages.count - 1 { Divider() }
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await model.load() }
        .safeAreaInset(edge: .bottom) {
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
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func collapsedMessageLabel(_ message: ThreadMessage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: message.direction == .outbound ? "person.crop.circle" : "envelope.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.direction == .outbound ? "Me" : message.fromAddress)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(message.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !message.attachments.isEmpty {
                Image(systemName: "paperclip")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Has attachments")
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Expands this older message")
    }

    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                onReply(model.actionTargetID)
            } label: {
                Image(systemName: "arrowshape.turn.up.left")
            }
            .accessibilityLabel("Reply")

            Menu {
                Button {
                    Task { await perform(model.isRead ? .unread : .read) }
                } label: {
                    Label(
                        model.isRead ? "Mark as Unread" : "Mark as Read",
                        systemImage: model.isRead ? "envelope.badge" : "envelope.open"
                    )
                }

                Button {
                    Task { await perform(model.isStarred ? .unstar : .star) }
                } label: {
                    Label(
                        model.isStarred ? "Remove Star" : "Star",
                        systemImage: model.isStarred ? "star.slash" : "star"
                    )
                }

                Button {
                    Task { await perform(model.isArchived ? .unarchive : .archive, exitsReader: !model.isArchived) }
                } label: {
                    Label(
                        model.isArchived ? "Move to Inbox" : "Archive",
                        systemImage: model.isArchived ? "tray.and.arrow.up" : "archivebox"
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
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Conversation actions")
            .disabled(model.actionInProgress != nil)
        }
    }

    private func perform(_ action: MailAction, exitsReader: Bool = false) async {
        pendingDestructiveAction = nil
        if await model.perform(action) {
            onMailboxMutation()
            if exitsReader { dismiss() }
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
