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

    /// Filled symbol used by empty-state glyphs for a bit more presence.
    var emptySystemImage: String {
        switch self {
        case .inbox: "tray.fill"
        case .archive: "archivebox.fill"
        case .starred: "star.fill"
        case .drafts: "doc.fill"
        case .sent: "paperplane.fill"
        case .trash: "trash.fill"
        }
    }

    var emptyTitle: String {
        switch self {
        case .inbox: "You're All Caught Up"
        case .archive: "Nothing Archived Yet"
        case .starred: "No Starred Mail"
        case .drafts: "No Drafts"
        case .sent: "Nothing Sent Yet"
        case .trash: "Trash Is Empty"
        }
    }

    var emptyDescription: String {
        switch self {
        case .inbox: "When new mail arrives, it’ll show up here."
        case .archive: "Archive a conversation to tuck it away without deleting it."
        case .starred: "Star something important and it’ll live here for quick access."
        case .drafts: "Saved drafts will wait here until you’re ready to send."
        case .sent: "Messages you send will collect here."
        case .trash: "Deleted conversations stay here until they’re purged."
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
