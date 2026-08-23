import SwiftUI

struct ThreadSummaryRow: View {
    let thread: ThreadSummary
    let mailbox: MailboxKind
    var isWorking = false

    private var people: String {
        let visibleParticipants: [ThreadParticipant]
        if mailbox == .drafts || mailbox == .sent {
            let recipients = thread.participants.filter { !$0.selfParticipant }
            visibleParticipants = recipients.isEmpty ? thread.participants : recipients
        } else {
            visibleParticipants = thread.participants.filter { !$0.selfParticipant }
        }

        let labels = visibleParticipants.map(\.label).filter { !$0.isEmpty }
        if !labels.isEmpty { return labels.joined(separator: ", ") }
        return mailbox == .drafts ? "No Recipient" : "Unknown Sender"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(thread.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 7)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(people)
                        .fontWeight(thread.isRead ? .regular : .semibold)
                        .lineLimit(1)

                    if thread.messageCount > 1 {
                        Text("\(thread.messageCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    if thread.isDraft {
                        Text("Draft")
                            .foregroundStyle(.red)
                    }

                    Text(thread.subject.isEmpty ? "(No Subject)" : thread.subject)
                        .fontWeight(thread.isRead ? .regular : .medium)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if thread.isStarred {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Starred")
                    }

                    if thread.hasAttachments {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Has attachments")
                    }

                    if mailbox == .sent, let status = thread.status {
                        Image(systemName: status.systemImage)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(status.accessibilityLabel)
                    }
                }
                .font(.subheadline)

                if !thread.preview.isEmpty {
                    Text(thread.preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isWorking ? 0.55 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(thread.isRead ? "Read" : "Unread")
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
