import SwiftUI

extension MailboxKind {
    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .archive: "Archive"
        case .starred: "Starred"
        case .drafts: "Drafts"
        case .sent: "Sent"
        case .trash: "Trash"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray"
        case .archive: "archivebox"
        case .starred: "star"
        case .drafts: "doc"
        case .sent: "paperplane"
        case .trash: "trash"
        }
    }

    var emptyTitle: String {
        switch self {
        case .inbox: "No Mail"
        case .archive: "Archive Is Empty"
        case .starred: "No Starred Messages"
        case .drafts: "No Drafts"
        case .sent: "Nothing Sent Yet"
        case .trash: "Trash Is Empty"
        }
    }

    var emptyDescription: String {
        switch self {
        case .inbox: "New messages appear here."
        case .archive: "Messages you archive appear here."
        case .starred: "Star important conversations to find them quickly."
        case .drafts: "Messages you save for later appear here."
        case .sent: "Messages you send appear here."
        case .trash: "Deleted messages appear here."
        }
    }
}

extension DeliveryStatus {
    var systemImage: String {
        switch self {
        case .queued: "clock"
        case .sent: "paperplane"
        case .delivered: "checkmark.circle"
        case .delayed: "clock.badge.exclamationmark"
        case .bounced, .complained, .failed: "exclamationmark.triangle"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .queued: "Queued"
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .delayed: "Delayed"
        case .bounced: "Bounced"
        case .complained: "Reported as spam"
        case .failed: "Failed"
        }
    }
}
