package dev.anuz.quickinbox.domain

import java.util.Date

internal fun ThreadDetail.applying(action: MailAction): ThreadDetail {
    val now = Date()
    return copy(
        messages = messages.map { message ->
            when (action) {
                MailAction.Read -> message.copy(isRead = true)
                MailAction.Unread -> message.copy(isRead = false)
                MailAction.Star -> message.copy(isStarred = true)
                MailAction.Unstar -> message.copy(isStarred = false)
                MailAction.Archive -> message.copy(archivedAt = message.archivedAt ?: now)
                MailAction.Unarchive -> message.copy(archivedAt = null)
                MailAction.Trash -> message.copy(deletedAt = message.deletedAt ?: now)
                MailAction.Restore -> message.copy(deletedAt = null)
                else -> message
            }
        }
    )
}
