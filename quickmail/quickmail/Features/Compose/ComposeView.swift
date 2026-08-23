import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ComposeViewModel
    @State private var isFileImporterPresented = false
    @State private var isDiscardConfirmationPresented = false

    private let onSent: (SendMessageResponse) -> Void

    init(
        api: QuickMailAPI,
        mode: ComposeMode = .newMessage,
        addresses: [MailAddress] = [],
        onSent: @escaping (SendMessageResponse) -> Void = { _ in }
    ) {
        _model = StateObject(
            wrappedValue: ComposeViewModel(api: api, mode: mode, addresses: addresses)
        )
        self.onSent = onSent
    }

    var body: some View {
        NavigationStack {
            Form {
                recipientsSection
                messageSection
                attachmentsSection

                if let errorMessage = model.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
            }
            .navigationTitle(model.mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .disabled(model.isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if model.isSending {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Sending")
                        } else {
                            Text("Send")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!model.canSend)
                }
            }
            .task {
                await model.loadAddressesIfNeeded()
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                Task { await model.importFiles(result) }
            }
            .confirmationDialog(
                model.isReply ? "Discard this reply?" : "Discard this message?",
                isPresented: $isDiscardConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your changes and attachments will be lost.")
            }
            .interactiveDismissDisabled(model.isSending || model.hasUnsavedChanges)
        }
    }

    @ViewBuilder
    private var recipientsSection: some View {
        Section {
            fromAddressPicker

            if model.isReply {
                LabeledContent("To", value: model.to)
                LabeledContent("Subject", value: model.subject)
            } else {
                recipientField("To", text: $model.to, prompt: "recipient@example.com")
                recipientField("Cc", text: $model.cc, prompt: "Optional, comma separated")
                recipientField("Bcc", text: $model.bcc, prompt: "Optional, comma separated")
                TextField("Subject", text: $model.subject, prompt: Text("Subject"))
                    .textInputAutocapitalization(.sentences)
            }
        }
    }

    @ViewBuilder
    private var fromAddressPicker: some View {
        if model.isLoadingAddresses && model.addresses.isEmpty {
            HStack {
                Text("From")
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
        } else if model.addresses.isEmpty {
            HStack {
                LabeledContent("From", value: "Unavailable")
                Button("Retry") {
                    Task { await model.retryLoadingAddresses() }
                }
                .buttonStyle(.borderless)
            }
        } else {
            Picker("From", selection: $model.selectedFromAddressID) {
                if model.isReply {
                    Text("Original mailbox").tag(String?.none)
                }
                ForEach(model.addresses) { address in
                    Text(addressDisplayName(address)).tag(Optional(address.id))
                }
            }
        }
    }

    private var messageSection: some View {
        Section("Message") {
            ZStack(alignment: .topLeading) {
                if model.body.isEmpty {
                    Text(model.isReply ? "Write a reply…" : "Write a message…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $model.body)
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Message body")
            }
        }
    }

    private var attachmentsSection: some View {
        Section {
            ForEach(model.attachments) { attachment in
                attachmentRow(attachment)
            }

            Button {
                isFileImporterPresented = true
            } label: {
                Label("Add Attachment", systemImage: "paperclip")
            }
            .disabled(
                model.isSending
                    || model.isImportingAttachments
                    || model.attachments.count >= ComposeViewModel.maximumAttachmentCount
            )

            if model.isImportingAttachments {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Preparing attachments…")
                        .foregroundStyle(.secondary)
                }
            }

            if let message = model.attachmentMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Attachments")
        } footer: {
            Text("Up to 5 files, 5 MB each. \(formattedByteCount(model.totalAttachmentBytes)) attached.")
        }
    }

    private func attachmentRow(_ attachment: ComposeAttachment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .lineLimit(1)
                Text(formattedByteCount(attachment.byteCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                model.removeAttachment(id: attachment.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(attachment.filename)")
            .disabled(model.isSending)
        }
    }

    private func recipientField(
        _ title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        TextField(title, text: text, prompt: Text(prompt))
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    private func addressDisplayName(_ address: MailAddress) -> String {
        guard let label = address.label?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty else {
            return address.address
        }
        return "\(label) · \(address.address)"
    }

    private func formattedByteCount(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    private func cancel() {
        if model.hasUnsavedChanges {
            isDiscardConfirmationPresented = true
        } else {
            dismiss()
        }
    }

    private func submit() {
        Task {
            guard let response = await model.send() else { return }
            onSent(response)
            dismiss()
        }
    }
}
