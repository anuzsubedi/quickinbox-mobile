import SwiftUI

struct ThreadSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let thread: ThreadSummary
    let mailbox: MailboxKind
    var isWorking = false

    private var people: String {
        let otherParticipants = thread.participants.filter { !$0.selfParticipant }
        let preferredParticipants = otherParticipants.isEmpty ? thread.participants : otherParticipants
        let labels = preferredParticipants.compactMap { participant -> String? in
            let label = participant.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty { return label }
            let address = participant.address.trimmingCharacters(in: .whitespacesAndNewlines)
            return address.isEmpty ? nil : address
        }

        if !labels.isEmpty { return labels.joined(separator: ", ") }
        return mailbox == .drafts ? "No Recipient" : "Unknown Sender"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if dynamicTypeSize < .xxxLarge {
                PostmarkSeal(name: people, isUnread: !thread.isRead)
            }

            if dynamicTypeSize >= .xxxLarge {
                expandedContent
            } else {
                compactContent
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(people)
                    .font(.body)
                    .fontWeight(thread.isRead ? .medium : .semibold)
                    .lineLimit(1)
                    .layoutPriority(1)

                if thread.messageCount > 1 {
                    Text("(\(thread.messageCount))")
                        .font(.caption)
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 6)

                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if thread.isDraft {
                    Text("Draft")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }

                Text(subject)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 4)
                metadataIcons
            }
            .font(.subheadline.weight(thread.isRead ? .regular : .medium))

            if !thread.preview.isEmpty {
                Text(thread.preview)
                    .font(.subheadline)
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .overlay(alignment: .trailing) {
            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 8)
                    .background(QuickMailDesign.Palette.paper)
                    .accessibilityLabel("Updating conversation")
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                unreadDot
                Text(people)
                    .fontWeight(thread.isRead ? .regular : .semibold)
                if thread.messageCount > 1 {
                    Text("(\(thread.messageCount))")
                        .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                        .monospacedDigit()
                }
            }

            Text(relativeDate)
                .font(.caption)
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if thread.isDraft {
                    Text("Draft")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
                Text(subject)
                    .fontWeight(thread.isRead ? .regular : .medium)
            }

            if !thread.preview.isEmpty {
                Text(thread.preview)
                    .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                metadataIcons
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Updating conversation")
                }
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var unreadDot: some View {
        if !thread.isRead {
            Circle()
                .fill(QuickMailDesign.Palette.sage)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var metadataIcons: some View {
        if thread.isStarred {
            Image(systemName: "star.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Starred")
        }

        if thread.hasAttachments {
            Image(systemName: "paperclip")
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .accessibilityLabel("Has attachments")
        }

        if mailbox == .sent, let status = thread.status {
            Image(systemName: status.systemImage)
                .foregroundStyle(QuickMailDesign.Palette.secondaryText)
                .accessibilityLabel(status.accessibilityLabel)
        }
    }

    private var subject: String {
        thread.subject.isEmpty ? "(No Subject)" : thread.subject
    }

    private var accessibilityLabel: String {
        var parts = [people, subject]
        if thread.messageCount > 1 {
            parts.append("\(thread.messageCount) messages")
        }
        if !thread.preview.isEmpty {
            parts.append(thread.preview)
        }
        parts.append(relativeDate)
        if thread.isStarred { parts.append("Starred") }
        if thread.hasAttachments { parts.append("Has attachments") }
        if mailbox == .sent, let status = thread.status {
            parts.append(status.accessibilityLabel)
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityValue: String {
        var values = [thread.isRead ? "Read" : "Unread"]
        if thread.isDraft { values.append("Draft") }
        if isWorking { values.append("Updating") }
        return values.joined(separator: ", ")
    }

    private var relativeDate: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(thread.createdAt) {
            return thread.createdAt.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDate(thread.createdAt, equalTo: Date(), toGranularity: .weekOfYear) {
            return thread.createdAt.formatted(.dateTime.weekday(.abbreviated))
        }
        if calendar.isDate(thread.createdAt, equalTo: Date(), toGranularity: .year) {
            return thread.createdAt.formatted(.dateTime.month(.abbreviated).day())
        }
        return thread.createdAt.formatted(.dateTime.year().month(.abbreviated).day())
    }
}

private struct PostmarkSeal: View {
    let name: String
    let isUnread: Bool

    var body: some View {
        ZStack {
            ParticipantMonogram(name: name, isEmphasized: isUnread, size: 38)

            Circle()
                .trim(from: isUnread ? 0.08 : 0, to: isUnread ? 0.82 : 1)
                .stroke(
                    isUnread ? QuickMailDesign.Palette.sage : QuickMailDesign.Palette.hairline,
                    style: StrokeStyle(
                        lineWidth: isUnread ? 2 : 0.5,
                        lineCap: isUnread ? .round : .butt
                    )
                )
                .rotationEffect(.degrees(isUnread ? -35 : 0))
                .frame(width: 42, height: 42)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
