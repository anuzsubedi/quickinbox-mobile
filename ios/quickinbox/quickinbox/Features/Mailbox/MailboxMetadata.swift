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
        case .inbox: "Your Inbox Is Clear"
        case .archive: "Nothing Archived"
        case .starred: "No Starred Conversations"
        case .drafts: "No Drafts"
        case .sent: "No Sent Mail"
        case .trash: "Trash Is Empty"
        }
    }

    var emptyDescription: String {
        switch self {
        case .inbox: "New conversations will appear here."
        case .archive: "Conversations you archive will appear here."
        case .starred: "Star a conversation to keep it close."
        case .drafts: "Messages you save will appear here."
        case .sent: "Messages you send will appear here."
        case .trash: "Deleted conversations will appear here."
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
