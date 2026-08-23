import Foundation

nonisolated enum MailboxKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case inbox
    case archive
    case starred
    case drafts
    case sent
    case trash

    var id: Self { self }
}

nonisolated enum MessageDirection: String, Codable, Sendable {
    case inbound
    case outbound
}

nonisolated enum DeliveryStatus: String, Codable, Sendable {
    case queued
    case sent
    case delivered
    case delayed
    case bounced
    case complained
    case failed
}

nonisolated struct ThreadParticipant: Codable, Hashable, Sendable {
    let label: String
    let address: String
    let selfParticipant: Bool

    enum CodingKeys: String, CodingKey {
        case label, address
        case selfParticipant = "self"
    }
}

nonisolated struct ThreadSummary: Codable, Identifiable, Equatable, Sendable {
    let threadID: String
    let latestID: String
    let subject: String
    let preview: String
    let participants: [ThreadParticipant]
    let messageCount: Int
    let isRead: Bool
    let isStarred: Bool
    let isDraft: Bool
    let isArchived: Bool
    let hasAttachments: Bool
    let domainID: String?
    let status: DeliveryStatus?
    let createdAt: Date

    var id: String { threadID }

    enum CodingKeys: String, CodingKey {
        case subject, preview, participants, status
        case threadID = "thread_id"
        case latestID = "latest_id"
        case messageCount = "message_count"
        case isRead = "is_read"
        case isStarred = "is_starred"
        case isDraft = "is_draft"
        case isArchived = "is_archived"
        case hasAttachments = "has_attachments"
        case domainID = "domain_id"
        case createdAt = "created_at"
    }
}

nonisolated struct MailboxPage: Codable, Equatable, Sendable {
    let threads: [ThreadSummary]
    let total: Int
    let page: Int
    let pageCount: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case threads, total, page
        case pageCount = "pageCount"
        case pageSize = "pageSize"
    }
}

nonisolated struct ThreadDetail: Codable, Equatable, Sendable {
    let threadID: String
    let subject: String
    let messages: [ThreadMessage]

    enum CodingKeys: String, CodingKey {
        case subject, messages
        case threadID = "threadId"
    }
}

nonisolated struct ThreadMessage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let direction: MessageDirection
    let fromAddress: String
    let toAddress: String
    let ccAddress: String?
    let subject: String
    let bodyText: String?
    let bodyHTML: String?
    let messageID: String?
    let referencesHeader: String?
    let status: DeliveryStatus?
    let statusDetail: String?
    let isRead: Bool
    let isStarred: Bool
    let deletedAt: Date?
    let archivedAt: Date?
    let createdAt: Date
    let attachments: [EmailAttachment]

    enum CodingKeys: String, CodingKey {
        case id, direction, subject, status, attachments
        case fromAddress = "from_addr"
        case toAddress = "to_addr"
        case ccAddress = "cc_addr"
        case bodyText = "body_text"
        case bodyHTML = "body_html"
        case messageID = "message_id"
        case referencesHeader = "references_header"
        case statusDetail = "status_detail"
        case isRead = "is_read"
        case isStarred = "is_starred"
        case deletedAt = "deleted_at"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
    }
}

nonisolated struct EmailAttachment: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let emailID: String?
    let filename: String
    let contentType: String
    let sizeBytes: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, filename
        case emailID = "email_id"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
    }
}

nonisolated struct MailboxFilters: Equatable, Sendable {
    var query = ""
    var unreadOnly = false
    var starredOnly = false
    var attachmentsOnly = false
    var domainID: String?
}

nonisolated enum MailAction: String, Codable, Sendable {
    case read
    case unread
    case star
    case unstar
    case archive
    case unarchive
    case trash
    case restore
    case delete
    case readAll = "read-all"
    case emptyTrash = "empty-trash"
}

nonisolated struct MailboxCounts: Codable, Equatable, Sendable {
    let inbox: Int
    let inboxUnread: Int
    let archive: Int
    let starred: Int
    let drafts: Int
    let sent: Int
    let trash: Int

    enum CodingKeys: String, CodingKey {
        case inbox, archive, starred, drafts, sent, trash
        case inboxUnread = "inbox_unread"
    }
}

nonisolated struct MailActionResponse: Decodable, Sendable {
    let ok: Bool
    let affected: Int
    let counts: MailboxCounts
}

nonisolated struct ThreadFlags: Encodable, Sendable {
    var isRead: Bool?
    var isStarred: Bool?
    var archived: Bool?
    var trashed: Bool?
    var messageOnly: Bool?
}

nonisolated struct OutboundAttachment: Codable, Equatable, Sendable {
    let filename: String
    let type: String
    let content: String
}

nonisolated struct ComposeMessage: Encodable, Equatable, Sendable {
    var draftID: String?
    var fromAddressID: String?
    var to: String
    var cc: String?
    var bcc: String?
    var subject: String
    var text: String?
    var html: String?
    var attachments: [OutboundAttachment]?

    enum CodingKeys: String, CodingKey {
        case to, cc, bcc, subject, text, html, attachments
        case draftID = "draftId"
        case fromAddressID = "fromAddressId"
    }
}

nonisolated struct ReplyMessage: Encodable, Equatable, Sendable {
    var fromAddressID: String?
    var text: String?
    var html: String?
    var attachments: [OutboundAttachment]?

    enum CodingKeys: String, CodingKey {
        case text, html, attachments
        case fromAddressID = "fromAddressId"
    }
}

nonisolated struct SendMessageResponse: Decodable, Sendable {
    let ok: Bool?
    let id: String
}

nonisolated struct MutationResponse: Decodable, Sendable {
    let ok: Bool
}
