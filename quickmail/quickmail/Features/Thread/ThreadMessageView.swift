import SwiftUI

struct ThreadMessageView: View {
    let message: ThreadMessage
    let isNewest: Bool
    let downloadingAttachmentID: String?
    let openAttachment: (ThreadMessage, EmailAttachment) -> Void

    @State private var showsFormattedHTML = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            messageBody
            if !message.attachments.isEmpty {
                attachmentList
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ParticipantMonogram(name: senderTitle, isEmphasized: isNewest, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(senderTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(message.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(senderTitle)
                            .font(.headline)
                        Text(message.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("To: \(message.toAddress)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if let cc = message.ccAddress, !cc.isEmpty {
                    Text("Cc: \(cc)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if message.direction == .outbound, let status = message.status {
                    Label(deliveryLabel(status), systemImage: deliverySymbol(status))
                        .font(.caption)
                        .foregroundStyle(deliveryColor(status))
                }
            }
        }
    }

    @ViewBuilder
    private var messageBody: some View {
        let plainText = message.bodyText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let html = message.bodyHTML?.trimmingCharacters(in: .whitespacesAndNewlines)

        if showsFormattedHTML, let html, !html.isEmpty {
            HardenedHTMLView(html: html)
        } else if let plainText, !plainText.isEmpty {
            PlainMessageBody(text: plainText)
        } else if let html, !html.isEmpty {
            HardenedHTMLView(html: html)
        } else {
            Text("This message has no readable body.")
                .foregroundStyle(.secondary)
                .italic()
        }

        if let html, !html.isEmpty, let plainText, !plainText.isEmpty {
            Button(showsFormattedHTML ? "Show Plain Text" : "Show Formatted Message") {
                showsFormattedHTML.toggle()
            }
            .font(.caption)
        }
    }

    private var attachmentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.attachments.count == 1 ? "Attachment" : "Attachments")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            ForEach(Array(message.attachments.enumerated()), id: \.element.id) { index, attachment in
                if index > 0 {
                    Divider()
                }

                Button {
                    openAttachment(message, attachment)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: attachmentSymbol(for: attachment.contentType))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attachment.filename)
                                .font(.subheadline)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if attachment.sizeBytes > 0 {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.sizeBytes), countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        if downloadingAttachmentID == attachment.id {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .disabled(downloadingAttachmentID != nil)
                .accessibilityHint("Previews this attachment")
            }
        }
        .padding(.top, 4)
    }

    private var senderTitle: String {
        message.direction == .outbound ? "Me" : message.fromAddress
    }

    private func deliveryLabel(_ status: DeliveryStatus) -> String {
        switch status {
        case .queued: "Queued"
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .delayed: "Delayed"
        case .bounced: "Bounced"
        case .complained: "Reported as spam"
        case .failed: "Failed"
        }
    }

    private func deliverySymbol(_ status: DeliveryStatus) -> String {
        switch status {
        case .queued: "clock"
        case .sent: "paperplane"
        case .delivered: "checkmark.circle"
        case .delayed: "clock.badge.exclamationmark"
        case .bounced, .complained, .failed: "exclamationmark.triangle"
        }
    }

    private func deliveryColor(_ status: DeliveryStatus) -> Color {
        switch status {
        case .bounced, .complained, .failed: .red
        case .delayed: .orange
        default: .secondary
        }
    }

    private func attachmentSymbol(for contentType: String) -> String {
        if contentType.hasPrefix("image/") { return "photo" }
        if contentType == "application/pdf" { return "doc.richtext" }
        if contentType.hasPrefix("audio/") { return "waveform" }
        if contentType.hasPrefix("video/") { return "film" }
        return "doc"
    }
}

private struct PlainMessageBody: View {
    let text: String

    var body: some View {
        let parts = QuotedTextParser.split(text)
        VStack(alignment: .leading, spacing: 12) {
            Text(parts.message)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let history = parts.quotedHistory {
                DisclosureGroup("Show quoted history") {
                    Text(history)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .font(.subheadline)
            }
        }
    }
}
