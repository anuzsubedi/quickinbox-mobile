import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: ComposeViewModel
    @State private var isFileImporterPresented = false
    @State private var isDiscardConfirmationPresented = false
    @State private var showsCarbonCopyFields = false
    @FocusState private var focusedField: ComposeField?

    private var composeBodyFont: Font {
        .body
    }

    private let onSent: (SendMessageResponse) -> Void

    init(
        api: QuickInboxAPI,
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
            ScrollView {
                VStack(spacing: 0) {
                    addressHeader
                    fieldDivider
                    subjectRow
                    QuickInboxRule()
                    attachmentArea
                    messageEditor
                    guidanceArea
                }
                .padding(.horizontal, horizontalInset)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: QuickInboxDesign.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .font(composeBodyFont)
            }
            .background(QuickInboxDesign.Palette.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(composeTitle)
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
                                .tint(QuickInboxDesign.Palette.interactiveTint)
                                .accessibilityLabel("Sending")
                        } else {
                            Text("Send")
                        }
                    }
                    .tint(QuickInboxDesign.Palette.interactiveTint)
                    .disabled(!model.canSend)
                }
            }
            .task {
                await model.loadAddressesIfNeeded()
                await model.loadDraftIfNeeded()
                if !model.cc.isEmpty || !model.bcc.isEmpty {
                    showsCarbonCopyFields = true
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                Task { await model.importFiles(result) }
            }
            .confirmationDialog(
                discardTitle,
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

    private var addressHeader: some View {
        VStack(spacing: 0) {
            fromAddressPicker

            fieldDivider

            if model.isReply {
                readOnlyField("To", value: model.to)
            } else {
                adaptiveFieldRow {
                    fieldLabel("To")
                    TextField("recipient@example.com", text: $model.to)
                        .focused($focusedField, equals: .to)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = showsCarbonCopyFields ? .cc : .subject
                        }
                        .accessibilityLabel("To")

                    if !showsCarbonCopyFields {
                        Button("Cc/Bcc") {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                                showsCarbonCopyFields = true
                            }
                            focusedField = .cc
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .accessibilityHint("Shows carbon copy and blind carbon copy address fields")
                    }
                }
                .frame(minHeight: fieldMinimumHeight)

                if showsCarbonCopyFields {
                    fieldDivider
                    recipientField(
                        "Cc",
                        text: $model.cc,
                        prompt: "Optional",
                        field: .cc,
                        nextField: .bcc
                    )
                    fieldDivider
                    recipientField(
                        "Bcc",
                        text: $model.bcc,
                        prompt: "Optional",
                        field: .bcc,
                        nextField: .subject
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: showsCarbonCopyFields)
    }

    @ViewBuilder
    private var fromAddressPicker: some View {
        adaptiveFieldRow {
            fieldLabel("From")

            if model.isLoadingAddresses && model.addresses.isEmpty {
                HStack(spacing: 10) {
                    Text("Loading sending addresses…")
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    Spacer(minLength: 8)
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Loading sending addresses")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.addresses.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    EmptyStateGlyph(
                        systemImage: "at.badge.minus",
                        tone: .muted,
                        size: 36,
                        iconSize: 15
                    )
                    Text("No sending address available")
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    Spacer(minLength: 8)
                    Button("Retry") {
                        Task { await model.retryLoadingAddresses() }
                    }
                    .quickInboxBorderedButtonStyle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Picker("From", selection: $model.selectedFromAddressID) {
                    if model.isReply {
                        Text("Original mailbox").tag(String?.none)
                    }
                    ForEach(model.addresses) { address in
                        Text(addressDisplayName(address)).tag(Optional(address.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("From address")
            }
        }
        .frame(minHeight: fieldMinimumHeight)
    }

    @ViewBuilder
    private var subjectRow: some View {
        if model.isReply {
            readOnlyField("Subject", value: model.subject)
        } else {
            adaptiveFieldRow {
                fieldLabel("Subject")
                TextField("What’s this about?", text: $model.subject)
                    .focused($focusedField, equals: .subject)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .body }
                    .accessibilityLabel("Subject")
            }
            .frame(minHeight: fieldMinimumHeight + 4)
        }
    }

    private var messageEditor: some View {
        ZStack(alignment: .topLeading) {
            if model.body.isEmpty {
                Text(model.isReply ? "Write a reply…" : "Start writing…")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 15)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            TextEditor(text: $model.body)
                .focused($focusedField, equals: .body)
                .font(composeBodyFont)
                .lineSpacing(3)
                .frame(minHeight: editorMinimumHeight)
                .scrollContentBackground(.hidden)
                .accessibilityLabel("Message body")
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private var attachmentArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Attach Files", systemImage: "paperclip")
                }
                .fontWeight(.medium)
                .disabled(
                    model.isSending
                        || model.isImportingAttachments
                        || model.attachments.count >= ComposeViewModel.maximumAttachmentCount
                )

                if model.isImportingAttachments {
                    ProgressView()
                        .controlSize(.small)
                    Text("Adding files…")
                        .font(.subheadline)
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                }

                Spacer(minLength: 0)

                if !model.attachments.isEmpty {
                    Text(model.attachments.count == 1 ? "1 ATTACHMENT" : "\(model.attachments.count) ATTACHMENTS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        .tracking(0.5)
                        .contentTransition(.numericText())
                }
            }
            .frame(minHeight: 44)

            if !model.attachments.isEmpty {
                ForEach(model.attachments) { attachment in
                    attachmentRow(attachment)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Text("5 files max · 5 MB each · \(formattedByteCount(model.totalAttachmentBytes)) attached")
                    .font(.caption)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                    .contentTransition(.numericText())
            }

            if let message = model.attachmentMessage {
                guidanceLabel(message)
            }
        }
        .padding(.vertical, 4)
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: model.attachments)
    }

    @ViewBuilder
    private var guidanceArea: some View {
        if let errorMessage = model.errorMessage {
            guidanceLabel(errorMessage)
                .padding(.top, 6)
                .transition(.opacity)
        } else if model.hasUnsavedChanges, let validationMessage = model.validationMessage {
            guidanceLabel(validationMessage)
                .padding(.top, 6)
                .transition(.opacity)
        }
    }

    private func attachmentRow(_ attachment: ComposeAttachment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: attachmentSymbol(for: attachment.contentType))
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .font(.body.weight(.medium))
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .lineLimit(1)
                Text(formattedByteCount(attachment.byteCount))
                    .font(.caption)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
            }
            Spacer(minLength: 8)
            Button(role: .destructive) {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                    model.removeAttachment(id: attachment.id)
                }
                AppFeedback.play(.destructiveConfirmed)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(attachment.filename)")
            .disabled(model.isSending)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func recipientField(
        _ title: String,
        text: Binding<String>,
        prompt: String,
        field: ComposeField,
        nextField: ComposeField
    ) -> some View {
        adaptiveFieldRow {
            fieldLabel(title)
            TextField(prompt, text: text)
                .focused($focusedField, equals: field)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focusedField = nextField }
                .accessibilityLabel(title)
        }
        .frame(minHeight: fieldMinimumHeight)
    }

    private func readOnlyField(_ title: String, value: String) -> some View {
        adaptiveFieldRow(alignment: .firstTextBaseline) {
            fieldLabel(title)
            Text(value)
                .foregroundStyle(QuickInboxDesign.Palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(minHeight: fieldMinimumHeight)
        .accessibilityElement(children: .combine)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
            .frame(width: usesStackedFields ? nil : fieldLabelWidth, alignment: .leading)
    }

    private func guidanceLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.callout)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Action needed: \(message)")
    }

    private func attachmentSymbol(for contentType: String) -> String {
        if contentType.hasPrefix("image/") { return "photo" }
        if contentType == "application/pdf" { return "doc.richtext" }
        if contentType.hasPrefix("audio/") { return "waveform" }
        if contentType.hasPrefix("video/") { return "film" }
        return "doc"
    }

    private var fieldLabelWidth: CGFloat { 58 }
    private var fieldSpacing: CGFloat { 12 }
    private var horizontalInset: CGFloat { usesStackedFields ? 16 : 20 }
    private var fieldMinimumHeight: CGFloat { usesStackedFields ? 64 : 48 }
    private var editorMinimumHeight: CGFloat { usesStackedFields ? 280 : 340 }
    private var usesStackedFields: Bool { dynamicTypeSize.isAccessibilitySize }

    private var fieldDivider: some View {
        QuickInboxRule()
            .padding(.leading, usesStackedFields ? 0 : fieldLabelWidth + fieldSpacing)
    }

    @ViewBuilder
    private func adaptiveFieldRow<Content: View>(
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if usesStackedFields {
            VStack(alignment: .leading, spacing: 7, content: content)
                .padding(.vertical, 9)
        } else {
            HStack(alignment: alignment, spacing: fieldSpacing, content: content)
        }
    }

    private var composeTitle: String {
        model.isDraft ? "Edit Draft" : model.mode.navigationTitle
    }

    private var discardTitle: String {
        if model.isReply { return "Discard reply?" }
        if model.isDraft { return "Discard changes?" }
        return "Discard message?"
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

private enum ComposeField: Hashable {
    case to
    case cc
    case bcc
    case subject
    case body
}
