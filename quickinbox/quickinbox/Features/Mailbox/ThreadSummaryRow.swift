import SwiftUI

struct ThreadSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let thread: ThreadSummary
    let mailbox: MailboxKind
    var isWorking = false
    var isSelectionActive = false
    var isSelected = false

    private var people: String {
        let otherParticipants = thread.participants.filter { !$0.selfParticipant }
        let preferredParticipants = otherParticipants.isEmpty ? thread.participants : otherParticipants
        let labels = preferredParticipants.compactMap { participant -> String? in
            let label = participant.displayLabel
            return label.isEmpty ? nil : label
        }

        if !labels.isEmpty { return labels.joined(separator: ", ") }
        return mailbox == .drafts ? "No Recipient" : "Unknown Sender"
    }

    private var correspondent: String {
        mailbox == .sent || mailbox == .drafts ? "To: \(people)" : people
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if dynamicTypeSize < .xxxLarge || isSelectionActive {
                MailboxAvatar(
                    name: people,
                    isUnread: !thread.isRead,
                    isSelectionActive: isSelectionActive,
                    isSelected: isSelected
                )
            }

            if dynamicTypeSize >= .xxxLarge {
                expandedContent
            } else {
                compactContent
            }
        }
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .foregroundStyle(QuickInboxDesign.Palette.primaryText)
        .contentShape(Rectangle())
        .animation(
            QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.selection, reduceMotion: reduceMotion),
            value: thread.isRead
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(correspondent)
                    .font(thread.isRead
                        ? rowSenderFont(isUnread: false)
                        : rowSenderFont(isUnread: true))
                    .lineLimit(1)
                    .layoutPriority(1)

                if thread.messageCount > 1 {
                    Text("· \(thread.messageCount)")
                        .font(rowMetadataFont)
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    metadataIcons

                    Text(relativeDate)
                        .font(rowDateFont)
                        .foregroundStyle(
                            thread.isRead
                                ? AnyShapeStyle(QuickInboxDesign.Palette.secondaryText.opacity(0.85))
                                : AnyShapeStyle(QuickInboxDesign.Palette.interactiveTint)
                        )
                        .lineLimit(1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if thread.isDraft {
                    Text("Draft")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }

                Text(subject)
                    .font(thread.isRead
                        ? rowSubjectFont(isUnread: false)
                        : rowSubjectFont(isUnread: true))
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            if !thread.preview.isEmpty {
                Text(thread.preview)
                    .font(rowPreviewFont)
                    .foregroundStyle(
                        thread.isRead
                            ? AnyShapeStyle(QuickInboxDesign.Palette.secondaryText.opacity(0.72))
                            : AnyShapeStyle(QuickInboxDesign.Palette.secondaryText)
                    )
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
        .overlay(alignment: .trailing) {
            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 8)
                    .background(QuickInboxDesign.Palette.paper)
                    .accessibilityLabel("Updating conversation")
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                unreadStatusMark
                Text(correspondent)
                    .font(thread.isRead
                        ? rowSenderFont(isUnread: false)
                        : rowSenderFont(isUnread: true))
                if thread.messageCount > 1 {
                    Text("· \(thread.messageCount)")
                        .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                        .monospacedDigit()
                }
            }

            Text(relativeDate)
                .font(rowMetadataFont)
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if thread.isDraft {
                    Text("Draft")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
                Text(subject)
                    .font(thread.isRead
                        ? rowSubjectFont(isUnread: false)
                        : rowSubjectFont(isUnread: true))
            }

            if !thread.preview.isEmpty {
                Text(thread.preview)
                    .font(rowPreviewFont)
                    .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
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
    }

    @ViewBuilder
    private var unreadStatusMark: some View {
        if !thread.isRead {
            Circle()
                .fill(QuickInboxDesign.Palette.interactiveTint)
                .frame(width: 8, height: 8)
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
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityLabel("Has attachments")
        }

        if mailbox == .sent, let status = thread.status {
            Image(systemName: status.systemImage)
                .foregroundStyle(QuickInboxDesign.Palette.secondaryText)
                .accessibilityLabel(status.accessibilityLabel)
        }
    }

    private func rowSenderFont(isUnread: Bool) -> Font {
        return isUnread
            ? .body.bold()
            : .body
    }

    private func rowSubjectFont(isUnread: Bool) -> Font {
        return isUnread
            ? .subheadline.weight(.semibold)
            : .subheadline
    }

    private var rowPreviewFont: Font {
        .subheadline
    }

    private var rowMetadataFont: Font {
        .caption
    }

    private var rowDateFont: Font {
        .caption2
    }

    private var subject: String {
        thread.subject.isEmpty ? "(No Subject)" : thread.subject
    }

    private var accessibilityLabel: String {
        var parts = [correspondent, subject]
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

private struct MailboxAvatar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let name: String
    let isUnread: Bool
    let isSelectionActive: Bool
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelectionActive && isSelected {
                Circle()
                    .fill(QuickInboxDesign.Palette.interactiveTint)
                    .frame(width: 42, height: 42)

                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(QuickInboxDesign.Palette.onInteractive)
                    .transition(.opacity)
            } else {
                ParticipantMonogram(name: name, isEmphasized: false, size: 38)

                Circle()
                    .stroke(
                        isSelectionActive
                            ? QuickInboxDesign.Palette.interactiveTint.opacity(0.72)
                            : QuickInboxDesign.Palette.separator.opacity(0.7),
                        lineWidth: isSelectionActive ? 1.5 : 1
                    )
                    .frame(width: 42, height: 42)

                if isUnread && !isSelectionActive {
                    Circle()
                        .fill(QuickInboxDesign.Palette.interactiveTint)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .stroke(QuickInboxDesign.Palette.paper, lineWidth: 2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
        }
        .frame(width: 44, height: 44)
        .animation(
            QuickInboxDesign.Motion.resolved(QuickInboxDesign.Motion.selection, reduceMotion: reduceMotion),
            value: isSelected
        )
        .accessibilityHidden(true)
    }
}
