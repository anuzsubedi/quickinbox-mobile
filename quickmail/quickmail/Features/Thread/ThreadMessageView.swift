import SwiftUI

struct ThreadMessageView: View {
    let message: ThreadMessage
    let isNewest: Bool
    var showsHeader = true
    let downloadingAttachmentID: String?
    let openAttachment: (ThreadMessage, EmailAttachment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }
            if let status = deliveryIssue {
                Label(deliveryLabel(status), systemImage: deliverySymbol(status))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(deliveryColor(status))
            }
            messageBody
            if !message.attachments.isEmpty {
                attachmentList
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ParticipantMonogram(name: senderTitle, isEmphasized: isNewest, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(senderTitle)
                            .font(messageSenderFont)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(compactMessageDate(message.createdAt))
                            .font(messageMetadataFont)
                            .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(senderTitle)
                            .font(messageSenderFont)
                        Text(compactMessageDate(message.createdAt))
                            .font(messageMetadataFont)
                            .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    }
                }

                Text("To: \(message.toAddress)")
                    .font(messageRecipientFont)
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .textSelection(.enabled)

                if let cc = message.ccAddress, !cc.isEmpty {
                    Text("Cc: \(cc)")
                        .font(messageRecipientFont)
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .textSelection(.enabled)
                }

            }
        }
    }

    @ViewBuilder
    private var messageBody: some View {
        let plainText = message.bodyText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let html = message.bodyHTML?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let html, !html.isEmpty, HTMLMessageSanitizer.hasVisibleContent(html) {
            FormattedMessageBody(html: html)
        } else if let plainText, !plainText.isEmpty {
            PlainMessageBody(text: plainText)
        } else {
            Text("This message has no readable body.")
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .italic()
        }
    }

    private var attachmentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.attachments.count == 1 ? "Attachment" : "Attachments")
                .font(.caption.weight(.semibold))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .padding(.bottom, 2)

            ForEach(Array(message.attachments.enumerated()), id: \.element.id) { index, attachment in
                if index > 0 {
                    QuickMailRule()
                }

                Button {
                    openAttachment(message, attachment)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: attachmentSymbol(for: attachment.contentType))
                            .font(.body)
                            .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attachment.filename)
                                .font(.subheadline)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if attachment.sizeBytes > 0 {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.sizeBytes), countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                            }
                        }
                        Spacer(minLength: 8)
                        if downloadingAttachmentID == attachment.id {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "eye")
                                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
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

    private var messageSenderFont: Font {
        .body.weight(.semibold)
    }

    private var messageMetadataFont: Font {
        .caption
    }

    private var messageRecipientFont: Font {
        .footnote
    }

    private var deliveryIssue: DeliveryStatus? {
        guard message.direction == .outbound, let status = message.status else { return nil }
        switch status {
        case .delayed, .bounced, .complained, .failed:
            return status
        case .queued, .sent, .delivered:
            return nil
        }
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

private struct FormattedMessageBody: View {
    let html: String
    @AppStorage(AppPreferences.showRemoteImagesByDefault) private var showRemoteImagesByDefault = false
    @State private var showsQuotedHistory = false
    @State private var showsRemoteImagesForMessage = false

    var body: some View {
        let parts = HTMLQuotedContentParser.split(html)

        VStack(alignment: .leading, spacing: 10) {
            if HTMLMessageSanitizer.containsRemoteImages(html),
               !showRemoteImagesByDefault,
               !showsRemoteImagesForMessage {
                Button {
                    showsRemoteImagesForMessage = true
                } label: {
                    Label("Show Images", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Loads remote images that may allow the sender to track this open")
            }

            HardenedHTMLView(
                html: parts.message,
                loadsRemoteImages: showRemoteImagesByDefault || showsRemoteImagesForMessage
            )

            if let history = parts.quotedHistory {
                Button {
                    showsQuotedHistory.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(showsQuotedHistory ? 90 : 0))
                        Text(showsQuotedHistory ? "Hide quoted history" : "Show quoted history")
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .accessibilityValue(showsQuotedHistory ? "Expanded" : "Collapsed")

                if showsQuotedHistory {
                    HardenedHTMLView(
                        html: history,
                        loadsRemoteImages: showRemoteImagesByDefault || showsRemoteImagesForMessage
                    )
                }
            }
        }
    }
}

private struct PlainMessageBody: View {
    let text: String
    @State private var showsQuotedHistory = false

    var body: some View {
        let parts = QuotedTextParser.split(text)
        VStack(alignment: .leading, spacing: 12) {
            Text(parts.message)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let history = parts.quotedHistory {
                Button {
                    showsQuotedHistory.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(showsQuotedHistory ? 90 : 0))
                        Text(showsQuotedHistory ? "Hide quoted history" : "Show quoted history")
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)

                if showsQuotedHistory {
                    Text(history)
                        .font(.callout)
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
