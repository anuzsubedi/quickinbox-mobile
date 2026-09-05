package dev.anuz.quickinbox.ui.mailbox

import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadSummary
import dev.anuz.quickinbox.domain.MailAction

internal fun MailboxUiState.sameMailboxView(other: MailboxUiState) =
    mailbox == other.mailbox && searchText == other.searchText &&
        unreadOnly == other.unreadOnly && starredOnly == other.starredOnly

internal data class OptimisticMailboxMutation(
    val action: MailAction,
    val before: MailboxUiState,
    val ids: Set<String>
) {
    fun rollback(current: MailboxUiState): MailboxUiState {
        if (!before.sameMailboxView(current)) return current
        val rows = current.threads.toMutableList()
        var restored = 0
        before.threads.forEachIndexed { index, original ->
            if (original.id !in ids) return@forEachIndexed
            val present = rows.indexOfFirst { it.id == original.id }
            if (present >= 0) {
                // Preserve independent metadata changes made while the request was in flight.
                val row = rows[present]
                rows[present] = when (action) {
                    MailAction.Read, MailAction.Unread -> row.copy(isRead = original.isRead)
                    MailAction.Star, MailAction.Unstar -> row.copy(isStarred = original.isStarred)
                    MailAction.Archive, MailAction.Unarchive -> row.copy(isArchived = original.isArchived)
                    else -> row
                }
            } else {
                val next = before.threads.drop(index + 1).firstNotNullOfOrNull { following ->
                    rows.indexOfFirst { it.id == following.id }.takeIf { it >= 0 }
                }
                rows.add(next ?: rows.size, original)
                restored++
            }
        }
        return current.copy(threads = rows, total = current.total + restored)
    }
}

internal fun MailboxUiState.applyingMailboxAction(action: MailAction, thread: ThreadSummary): MailboxUiState {
    val current = threads.firstOrNull { it.id == thread.id } ?: return this
    val updated = when (action) {
        MailAction.Read ->
            if (unreadOnly) without(current)
            else replacing(current.copy(isRead = true))
        MailAction.Unread -> replacing(current.copy(isRead = false))
        MailAction.Star -> replacing(current.copy(isStarred = true))
        MailAction.Unstar ->
            if (starredOnly || mailbox == MailboxKind.Starred) without(current)
            else replacing(current.copy(isStarred = false))
        MailAction.Archive ->
            if (mailbox == MailboxKind.Inbox) without(current)
            else replacing(current.copy(isArchived = true))
        MailAction.Unarchive ->
            if (mailbox == MailboxKind.Archive) without(current)
            else replacing(current.copy(isArchived = false))
        MailAction.Trash, MailAction.Restore, MailAction.Delete -> without(current)
        MailAction.ReadAll, MailAction.EmptyTrash -> this
    }
    return updated
}

internal fun MailboxUiState.replacing(thread: ThreadSummary) = copy(
    threads = threads.map { if (it.id == thread.id) thread else it }
)

internal fun MailboxUiState.without(thread: ThreadSummary) = copy(
    threads = threads.filterNot { it.id == thread.id },
    total = maxOf(0, total - threads.count { it.id == thread.id })
)
