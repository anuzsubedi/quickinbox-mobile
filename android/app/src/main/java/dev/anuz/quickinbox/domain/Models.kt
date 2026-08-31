package dev.anuz.quickinbox.domain

import com.google.gson.annotations.SerializedName
import java.util.Date

data class User(
    val id: String = "",
    val email: String = "",
    val name: String = "",
    @SerializedName("is_admin") val isAdmin: Boolean = false,
    @SerializedName("created_at") val createdAt: Date? = null
)

data class Credential(
    val origin: String,
    val token: String,
    val expiresAt: Date,
    val cachedUser: User? = null
) {
    val isExpired: Boolean get() = !expiresAt.after(Date())

    fun caching(user: User) = copy(cachedUser = user)
}

data class CurrentUserResponse(val user: User)

data class PairingRequest(
    val code: String,
    val deviceName: String,
    val platform: String = "android"
)

data class PairingResponse(
    val token: String = "",
    val expiresAt: Date? = null
)

enum class MailboxKind(val apiValue: String, val title: String, val emptyTitle: String, val emptyDescription: String) {
    Inbox("inbox", "Inbox", "Your inbox is clear", "New conversations will appear here."),
    Archive("archive", "Archive", "Nothing archived", "Conversations you archive will appear here."),
    Starred("starred", "Starred", "No starred conversations", "Star a conversation to keep it close."),
    Drafts("drafts", "Drafts", "No drafts", "Messages you save will appear here."),
    Sent("sent", "Sent", "No sent mail", "Messages you send will appear here."),
    Trash("trash", "Trash", "Trash is empty", "Deleted conversations will appear here.");
}

data class MailboxFilters(
    val query: String = "",
    val unreadOnly: Boolean = false,
    val starredOnly: Boolean = false,
    val attachmentsOnly: Boolean = false,
    val domainId: String? = null
)

data class ThreadParticipant(
    val label: String = "",
    val address: String = "",
    @SerializedName("self") val selfParticipant: Boolean = false
) {
    val displayLabel: String
        get() {
            val cleanLabel = label.trim()
            val cleanAddress = address.trim()
            val addressOnly = EmailAddressPresentation.addressOnly(cleanAddress)
            val localPart = addressOnly.substringBefore("@")
            if (cleanLabel.isNotEmpty() &&
                !cleanLabel.equals(addressOnly, ignoreCase = true) &&
                !cleanLabel.equals(localPart, ignoreCase = true)
            ) {
                return cleanLabel
            }
            EmailAddressPresentation.explicitName(cleanAddress)?.let { return it }
            return addressOnly.ifEmpty { cleanLabel }
        }
}

data class ThreadSummary(
    @SerializedName("thread_id") val threadId: String = "",
    @SerializedName("latest_id") val latestId: String = "",
    val subject: String = "",
    val preview: String = "",
    val participants: List<ThreadParticipant> = emptyList(),
    @SerializedName("message_count") val messageCount: Int = 0,
    @SerializedName("is_read") val isRead: Boolean = false,
    @SerializedName("is_starred") val isStarred: Boolean = false,
    @SerializedName("is_draft") val isDraft: Boolean = false,
    @SerializedName("is_archived") val isArchived: Boolean = false,
    @SerializedName("has_attachments") val hasAttachments: Boolean = false,
    @SerializedName("domain_id") val domainId: String? = null,
    val status: String? = null,
    @SerializedName("created_at") val createdAt: Date? = null
) {
    val id: String get() = threadId
}

data class MailboxPage(
    val threads: List<ThreadSummary> = emptyList(),
    val total: Int = 0,
    val page: Int = 1,
    val pageCount: Int = 1,
    val pageSize: Int = 0
)

data class ThreadDetail(
    @SerializedName("threadId") val threadId: String = "",
    val subject: String = "",
    val messages: List<ThreadMessage> = emptyList()
)

data class ThreadMessage(
    val id: String = "",
    val direction: String = "",
    @SerializedName("from_addr") val fromAddress: String = "",
    @SerializedName("from_name") val fromName: String? = null,
    @SerializedName("to_addr") val toAddress: String = "",
    @SerializedName("cc_addr") val ccAddress: String? = null,
    val subject: String = "",
    @SerializedName("body_text") val bodyText: String? = null,
    @SerializedName("body_html") val bodyHtml: String? = null,
    @SerializedName("message_id") val messageId: String? = null,
    @SerializedName("references_header") val referencesHeader: String? = null,
    val status: String? = null,
    @SerializedName("status_detail") val statusDetail: String? = null,
    @SerializedName("is_read") val isRead: Boolean = false,
    @SerializedName("is_starred") val isStarred: Boolean = false,
    @SerializedName("deleted_at") val deletedAt: Date? = null,
    @SerializedName("archived_at") val archivedAt: Date? = null,
    @SerializedName("created_at") val createdAt: Date? = null,
    val attachments: List<EmailAttachment> = emptyList()
) {
    val senderDisplayName: String
        get() = fromName?.trim()?.takeIf { it.isNotEmpty() }
            ?: EmailAddressPresentation.displayLabel(fromAddress)
}

data class EmailAttachment(
    val id: String = "",
    @SerializedName("email_id") val emailId: String? = null,
    val filename: String = "",
    @SerializedName("content_type") val contentType: String = "",
    @SerializedName("size_bytes") val sizeBytes: Int = 0,
    @SerializedName("created_at") val createdAt: Date? = null
)

enum class MailAction(val apiValue: String) {
    Read("read"),
    Unread("unread"),
    Star("star"),
    Unstar("unstar"),
    Archive("archive"),
    Unarchive("unarchive"),
    Trash("trash"),
    Restore("restore"),
    Delete("delete"),
    ReadAll("read-all"),
    EmptyTrash("empty-trash")
}

data class MailActionBody(val action: String, val ids: List<String>)

data class MailboxCounts(
    val inbox: Int = 0,
    @SerializedName("inbox_unread") val inboxUnread: Int = 0,
    val archive: Int = 0,
    val starred: Int = 0,
    val drafts: Int = 0,
    val sent: Int = 0,
    val trash: Int = 0
)

data class MailActionResponse(
    val ok: Boolean = false,
    val affected: Int = 0,
    val counts: MailboxCounts? = null
)

data class ThreadFlags(
    val isRead: Boolean? = null,
    val isStarred: Boolean? = null,
    val archived: Boolean? = null,
    val trashed: Boolean? = null,
    val messageOnly: Boolean? = null
)

data class OutboundAttachment(
    val filename: String,
    val type: String,
    val content: String
)

data class ComposeMessage(
    @SerializedName("draftId") val draftId: String? = null,
    @SerializedName("fromAddressId") val fromAddressId: String? = null,
    val to: String,
    val cc: String? = null,
    val bcc: String? = null,
    val subject: String,
    val text: String? = null,
    val html: String? = null,
    val attachments: List<OutboundAttachment>? = null
)

data class DraftMessage(
    val id: String = "",
    @SerializedName(value = "fromAddress", alternate = ["from_addr"]) val fromAddress: String = "",
    val to: String = "",
    val cc: String? = null,
    val bcc: String? = null,
    val subject: String = "",
    val text: String? = null
)

data class DraftResponse(val draft: DraftMessage)

data class ReplyMessage(
    @SerializedName("fromAddressId") val fromAddressId: String? = null,
    val to: String? = null,
    val cc: String? = null,
    val bcc: String? = null,
    val text: String? = null,
    val html: String? = null,
    val attachments: List<OutboundAttachment>? = null
)

data class ForwardMessage(
    @SerializedName("fromAddressId") val fromAddressId: String? = null,
    val to: String,
    val cc: String? = null,
    val bcc: String? = null,
    val text: String? = null,
    val html: String? = null,
    val includeAttachments: Boolean = true
)

data class SendMessageResponse(
    val ok: Boolean? = null,
    val id: String = ""
)

data class MutationResponse(val ok: Boolean = false)

data class MailAddress(
    val id: String = "",
    @SerializedName("user_id") val userId: String = "",
    @SerializedName("domain_id") val domainId: String = "",
    @SerializedName("domain_name") val domainName: String = "",
    val address: String = "",
    val label: String? = null,
    @SerializedName("is_default") val isDefault: Boolean = false,
    val signature: String? = null,
    @SerializedName("created_at") val createdAt: Date? = null
)

data class AddressesResponse(val addresses: List<MailAddress> = emptyList())

data class SignatureUpdateRequest(val signature: String)

data class SignatureResponse(
    val ok: Boolean = false,
    val signature: String = ""
)

data class SignatureValueResponse(val signature: String = "")

data class DeviceSession(
    val id: String = "",
    @SerializedName("device_name") val deviceName: String? = null,
    @SerializedName("device_platform") val devicePlatform: String? = null,
    @SerializedName("created_at") val createdAt: Date? = null,
    @SerializedName("last_seen_at") val lastSeenAt: Date? = null,
    @SerializedName("expires_at") val expiresAt: Date? = null,
    @SerializedName("is_current") val isCurrent: Boolean = false
)

data class DevicesResponse(val devices: List<DeviceSession> = emptyList())

data class DownloadedAttachment(
    val file: java.io.File,
    val filename: String,
    val contentType: String
)

data class ServerErrorBody(val error: String = "")

object EmailAddressPresentation {
    fun displayLabel(value: String): String = explicitName(value) ?: addressOnly(value)

    fun explicitName(value: String): String? {
        val bracket = value.indexOf('<')
        if (bracket < 0) return null
        val name = value.substring(0, bracket).trim().trim('"')
        return name.takeIf { it.isNotEmpty() }
    }

    fun addressOnly(value: String): String {
        val trimmed = value.trim()
        val open = trimmed.indexOf('<')
        val close = trimmed.indexOf('>', startIndex = open + 1)
        if (open < 0 || close < 0) return trimmed
        return trimmed.substring(open + 1, close).trim()
    }
}
