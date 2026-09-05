package dev.anuz.quickinbox.ui.mailbox

import dev.anuz.quickinbox.domain.MailAction
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class MailboxUndoTest {
    @Test fun operationWaitsUntilSnackbarIsDismissed() = runTest {
        val decision = UndoDecision()
        var sent = false
        launch { if (!decision.isUndone()) sent = true }
        runCurrent()
        assertFalse(sent)
        advanceTimeBy(10_000)
        assertFalse(sent)
        decision.finish(false)
        runCurrent()
        assertTrue(sent)
    }

    @Test fun undoPreventsEvenPermanentDeletionAndWinsOverDismissal() = runTest {
        val decision = UndoDecision()
        var sent = false
        launch { if (!decision.isUndone()) sent = true }
        decision.finish(true)
        decision.finish(false) // Snackbar disposal follows the Undo click.
        runCurrent()
        assertFalse(sent)
        assertTrue(decision.isUndone())
    }

    @Test fun dismissalCommitsOnlyOnceAndCannotBeReversedAfterCommit() = runTest {
        val decision = UndoDecision()
        var calls = 0
        launch { if (!decision.isUndone()) calls++ }
        decision.finish(false)
        decision.finish(false)
        decision.finish(true)
        runCurrent()
        assertEquals(1, calls)
        assertFalse(decision.isUndone())
    }

    @Test fun supportedActionsIncludeAllDeleteArchiveEntryPoints() {
        for (action in listOf(MailAction.Archive, MailAction.Unarchive, MailAction.Trash, MailAction.Delete)) {
            assertTrue(action.supportsUndo())
        }
        assertFalse(MailAction.Read.supportsUndo())
        assertFalse(MailAction.Star.supportsUndo())
        assertEquals("3 conversations archived", MailboxUndoOffer(1, MailAction.Archive, 3).message)
    }
}
