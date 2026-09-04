package dev.anuz.quickinbox.domain

/** Toggle the majority state; ties become read. */
internal fun selectionReadAction(threads: List<ThreadSummary>): MailAction {
    val readCount = threads.count { it.isRead }
    return if (readCount > threads.size - readCount) MailAction.Unread else MailAction.Read
}
