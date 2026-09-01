import Combine
import Foundation
import UniformTypeIdentifiers

nonisolated enum ComposeMode: Equatable, Sendable {
    case newMessage
    case draft(draftID: String)
    case reply(messageID: String, recipient: String, subject: String)
    case forward(subject: String, body: String)

    var navigationTitle: String {
        switch self {
        case .newMessage: "New Message"
        case .draft: "Draft"
        case .reply: "Reply"
        case .forward: "Forward"
        }
    }

    var draftID: String? {
        if case .draft(let draftID) = self { draftID } else { nil }
    }
}

nonisolated struct ComposeAttachment: Identifiable, Equatable, Sendable {
    let id: UUID
    let filename: String
    let contentType: String
    let byteCount: Int
    let encodedContent: String

    init(
        id: UUID = UUID(),
        filename: String,
        contentType: String,
        byteCount: Int,
        encodedContent: String
    ) {
        self.id = id
        self.filename = filename
        self.contentType = contentType
        self.byteCount = byteCount
        self.encodedContent = encodedContent
    }

    var outboundValue: OutboundAttachment {
        OutboundAttachment(filename: filename, type: contentType, content: encodedContent)
    }
}

@MainActor
final class ComposeViewModel: ObservableObject {
    nonisolated static let maximumAttachmentCount = 5
    nonisolated static let maximumAttachmentBytes = 5 * 1_024 * 1_024
    nonisolated static let maximumTotalAttachmentBytes = 25 * 1_024 * 1_024

    @Published var to = ""
    @Published var cc = ""
    @Published var bcc = ""
    @Published var subject = ""
    @Published var body = ""
    @Published private(set) var addresses: [MailAddress]
    @Published var selectedFromAddressID: String?
    @Published private(set) var attachments: [ComposeAttachment] = []
    @Published private(set) var isLoadingAddresses = false
    @Published private(set) var isLoadingDraft = false
    @Published private(set) var isImportingAttachments = false
    @Published private(set) var isSending = false
    @Published var errorMessage: String?
    @Published var attachmentMessage: String?

    let mode: ComposeMode

    private let api: QuickInboxAPI
    private var didAttemptAddressLoad = false
    private var didAttemptDraftLoad = false

    init(api: QuickInboxAPI, mode: ComposeMode, addresses: [MailAddress] = []) {
        self.api = api
        self.mode = mode
        self.addresses = addresses

        switch mode {
        case .newMessage:
            selectedFromAddressID = Self.preferredAddress(in: addresses)?.id
        case .draft:
            selectedFromAddressID = nil
        case .reply(_, let recipient, let subject):
            to = recipient
            self.subject = subject
            // A nil selection lets the server reply from the mailbox that received
            // the original, including a catch-all address that is not saved.
            selectedFromAddressID = nil
        case .forward(let subject, let body):
            self.subject = subject
            self.body = body
            selectedFromAddressID = Self.preferredAddress(in: addresses)?.id
        }
    }

    var isReply: Bool {
        if case .reply = mode { true } else { false }
    }

    var isDraft: Bool { mode.draftID != nil }

    var totalAttachmentBytes: Int {
        attachments.reduce(0) { $0 + $1.byteCount }
    }

    var hasUnsavedChanges: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachments.isEmpty
            || (!isReply && (
                !to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !cc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !bcc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ))
    }

    var canSend: Bool {
        !isSending && !isImportingAttachments && !isLoadingDraft && validationMessage == nil
    }

    var validationMessage: String? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return "Write a message before sending." }

        switch mode {
        case .newMessage, .draft, .forward:
            guard selectedFromAddressID != nil else {
                return "Choose a sending address."
            }
            if let error = Self.recipientError(to, label: "To", required: true) { return error }
            if let error = Self.recipientError(cc, label: "Cc", required: false) { return error }
            if let error = Self.recipientError(bcc, label: "Bcc", required: false) { return error }

            let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSubject.isEmpty else { return "Add a subject." }
            guard trimmedSubject.count <= 200 else {
                return "The subject must be 200 characters or fewer."
            }
        case .reply:
            break
        }

        return nil
    }

    func loadAddressesIfNeeded() async {
        guard !didAttemptAddressLoad else { return }
        didAttemptAddressLoad = true
        await loadAddresses()
    }

    func loadDraftIfNeeded() async {
        guard !didAttemptDraftLoad, let draftID = mode.draftID else { return }
        didAttemptDraftLoad = true
        isLoadingDraft = true
        defer { isLoadingDraft = false }

        do {
            let draft = try await api.draft(id: draftID)

            to = draft.to
            cc = draft.cc ?? ""
            bcc = draft.bcc ?? ""
            subject = draft.subject
            body = draft.text ?? ""
            selectedFromAddressID = addresses.first(where: {
                $0.address.caseInsensitiveCompare(draft.fromAddress) == .orderedSame
            })?.id ?? Self.preferredAddress(in: addresses)?.id
        } catch {
            guard !Self.isUnauthorized(error) else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "QuickInbox couldn’t load this draft. Try again."
        }
    }

    func retryLoadingAddresses() async {
        await loadAddresses()
    }

    func importFiles(_ result: Result<[URL], Error>) async {
        attachmentMessage = nil

        let urls: [URL]
        do {
            urls = try result.get()
        } catch {
            // Cancellation is not an error that needs to replace the draft state.
            if (error as NSError).code != NSUserCancelledError {
                attachmentMessage = "The selected files could not be opened."
            }
            return
        }

        guard !urls.isEmpty else { return }
        isImportingAttachments = true
        defer { isImportingAttachments = false }

        var imported = attachments
        var messages: [String] = []

        for url in urls {
            guard imported.count < Self.maximumAttachmentCount else {
                messages.append("You can attach up to \(Self.maximumAttachmentCount) files.")
                break
            }

            do {
                let attachment = try await Self.readAttachment(from: url)
                guard imported.reduce(0, { $0 + $1.byteCount }) + attachment.byteCount
                        <= Self.maximumTotalAttachmentBytes else {
                    messages.append("Attachments cannot exceed 25 MB in total.")
                    continue
                }
                imported.append(attachment)
            } catch let error as AttachmentImportError {
                messages.append(error.localizedDescription)
            } catch {
                messages.append("\(url.lastPathComponent) could not be attached.")
            }
        }

        attachments = imported
        attachmentMessage = messages.isEmpty ? nil : messages.joined(separator: "\n")
    }

    func removeAttachment(id: ComposeAttachment.ID) {
        guard !isSending else { return }
        attachments.removeAll { $0.id == id }
        attachmentMessage = nil
    }

    func send() async -> SendMessageResponse? {
        // This guard is the final duplicate-submit barrier, independent of the UI.
        guard !isSending else { return nil }
        guard let validationMessage else {
            errorMessage = nil
            isSending = true
            defer { isSending = false }

            do {
                let response: SendMessageResponse
                let outboundAttachments = attachments.isEmpty
                    ? nil
                    : attachments.map(\.outboundValue)

                switch mode {
                case .newMessage, .draft, .forward:
                    response = try await api.send(
                        ComposeMessage(
                            draftID: mode.draftID,
                            fromAddressID: selectedFromAddressID,
                            to: to.trimmingCharacters(in: .whitespacesAndNewlines),
                            cc: Self.nilIfEmpty(cc),
                            bcc: Self.nilIfEmpty(bcc),
                            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                            text: body.trimmingCharacters(in: .whitespacesAndNewlines),
                            html: nil,
                            attachments: outboundAttachments
                        )
                    )
                case .reply(let messageID, _, _):
                    response = try await api.reply(
                        to: messageID,
                        message: ReplyMessage(
                            fromAddressID: selectedFromAddressID,
                            text: body.trimmingCharacters(in: .whitespacesAndNewlines),
                            html: nil,
                            attachments: outboundAttachments
                        )
                    )
                }

                AppFeedback.play(.messageSent)
                return response
            } catch {
                guard !Self.isUnauthorized(error) else { return nil }
                // Keep all entered fields and attachments intact so Retry is safe.
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "QuickInbox could not send this message. Try again."
                AppFeedback.error()
                return nil
            }
        }

        errorMessage = validationMessage
        AppFeedback.play(.warning)
        return nil
    }

    private func loadAddresses() async {
        guard !isLoadingAddresses else { return }
        isLoadingAddresses = true
        defer { isLoadingAddresses = false }

        do {
            let loaded = try await api.addresses()
            addresses = loaded
            if !isReply, selectedFromAddressID == nil {
                selectedFromAddressID = Self.preferredAddress(in: loaded)?.id
            }
            errorMessage = loaded.isEmpty
                ? "No sending address is configured. Add one in QuickInbox settings first."
                : nil
        } catch {
            guard !Self.isUnauthorized(error) else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Sending addresses could not be loaded."
        }
    }

    private static func isUnauthorized(_ error: Error) -> Bool {
        if let apiError = error as? APIError, apiError == .unauthorized { return true }
        return false
    }

    private static func preferredAddress(in addresses: [MailAddress]) -> MailAddress? {
        if let savedID = UserDefaults.standard.string(forKey: AppPreferences.selectedSendingAddressID),
           let saved = addresses.first(where: { $0.id == savedID }) {
            return saved
        }
        return addresses.first(where: \.isDefault) ?? addresses.first
    }

    private static func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func recipientError(
        _ value: String,
        label: String,
        required: Bool
    ) -> String? {
        let recipients = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if recipients.count == 1, recipients[0].isEmpty {
            return required ? "Add at least one recipient." : nil
        }
        if recipients.contains(where: \.isEmpty) {
            return "Remove the empty address from \(label)."
        }

        for recipient in recipients where !isValidEmail(recipient) {
            return "Check the email address in \(label): \(recipient)"
        }
        return nil
    }

    private static func isValidEmail(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace) else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        return parts[1].contains(".") && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
    }

    private nonisolated static func readAttachment(from url: URL) async throws -> ComposeAttachment {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            let values = try url.resourceValues(forKeys: [
                .contentTypeKey,
                .fileSizeKey,
                .isRegularFileKey,
                .nameKey
            ])
            let filename = values.name ?? url.lastPathComponent
            guard values.isRegularFile != false else {
                throw AttachmentImportError.notAFile(filename)
            }
            if let size = values.fileSize, size > maximumAttachmentBytes {
                throw AttachmentImportError.tooLarge(filename)
            }

            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard !data.isEmpty else { throw AttachmentImportError.empty(filename) }
            guard data.count <= maximumAttachmentBytes else {
                throw AttachmentImportError.tooLarge(filename)
            }

            return ComposeAttachment(
                filename: filename.isEmpty ? "attachment" : filename,
                contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream",
                byteCount: data.count,
                encodedContent: data.base64EncodedString()
            )
        }.value
    }
}

private nonisolated enum AttachmentImportError: LocalizedError {
    case empty(String)
    case notAFile(String)
    case tooLarge(String)

    var errorDescription: String? {
        switch self {
        case .empty(let filename): "\(filename) is empty."
        case .notAFile(let filename): "\(filename) is not a file."
        case .tooLarge(let filename): "\(filename) exceeds the 5 MB limit."
        }
    }
}
