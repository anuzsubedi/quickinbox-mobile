package dev.anuz.quickinbox.ui.mailbox

import dev.anuz.quickinbox.domain.*
import org.junit.Assert.*
import org.junit.Test

class OptimisticMailboxMutationTest {
    private val first = ThreadSummary(threadId = "first", latestId = "1", isRead = false, isStarred = false)
    private val second = ThreadSummary(threadId = "second", latestId = "2", isRead = false, isStarred = false)
    private val initial = MailboxUiState(threads = listOf(first, second), total = 2)

    @Test fun archiveAndStarAreAppliedLocallyBeforeAnyServerResponse() {
        val archived = initial.applyingMailboxAction(MailAction.Archive, first)
        assertEquals(listOf(second), archived.threads)
        assertEquals(1, archived.total)
        val starred = initial.applyingMailboxAction(MailAction.Star, first)
        assertTrue(starred.threads.first().isStarred)
    }

    @Test fun failedArchiveRestoresItsRowWithoutRevertingAnotherSuccessfulAction() {
        val transaction = OptimisticMailboxMutation(MailAction.Archive, initial, setOf(first.id))
        val changed = initial.applyingMailboxAction(MailAction.Archive, first)
            .applyingMailboxAction(MailAction.Star, second)
        val restored = transaction.rollback(changed)
        assertEquals(listOf(first.id, second.id), restored.threads.map { it.id })
        assertTrue(restored.threads.last().isStarred)
        assertEquals(2, restored.total)
    }

    @Test fun failedStarOnlyRestoresTheStarField() {
        val transaction = OptimisticMailboxMutation(MailAction.Star, initial, setOf(first.id))
        val changed = initial.applyingMailboxAction(MailAction.Star, first)
            .applyingMailboxAction(MailAction.Read, first)
        val restored = transaction.rollback(changed)
        assertFalse(restored.threads.first().isStarred)
        assertTrue(restored.threads.first().isRead)
    }

    @Test fun rollbackDoesNotInsertEmailsIntoADifferentMailboxOrSearch() {
        val transaction = OptimisticMailboxMutation(MailAction.Archive, initial, setOf(first.id))
        val archive = MailboxUiState(mailbox = MailboxKind.Archive)
        val search = MailboxUiState(searchText = "different")
        assertEquals(archive, transaction.rollback(archive))
        assertEquals(search, transaction.rollback(search))
    }

    @Test fun reapplyingAPendingRemovalDoesNotDoubleDecrementTheCount() {
        val changed = initial.applyingMailboxAction(MailAction.Trash, first)
        assertEquals(changed, changed.applyingMailboxAction(MailAction.Trash, first))
    }
}
