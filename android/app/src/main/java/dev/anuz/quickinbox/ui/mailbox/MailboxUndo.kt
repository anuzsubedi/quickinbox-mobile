package dev.anuz.quickinbox.ui.mailbox

import dev.anuz.quickinbox.domain.MailAction
import kotlinx.coroutines.CompletableDeferred

internal fun MailAction.supportsUndo() = this in setOf(MailAction.Archive, MailAction.Unarchive, MailAction.Trash, MailAction.Delete)

/** First decision wins: undo can never race a timeout into sending the operation. */
internal class UndoDecision {
    private val result = CompletableDeferred<Boolean>()
    fun finish(undo: Boolean) { result.complete(undo) }
    suspend fun isUndone(): Boolean = result.await()
}

data class MailboxUndoOffer(val id: Long, val action: MailAction, val count: Int) {
    val message: String get() {
        val subject = if (count == 1) "Conversation" else "$count conversations"
        return when (action) {
            MailAction.Archive -> "$subject archived"
            MailAction.Unarchive -> "$subject moved to Inbox"
            MailAction.Trash -> "$subject moved to Trash"
            MailAction.Delete -> "$subject deleted"
            else -> "$subject updated"
        }
    }
}
