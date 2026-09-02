package dev.anuz.quickinbox

import dev.anuz.quickinbox.data.SwipeControl
import dev.anuz.quickinbox.data.availableSwipeControls
import dev.anuz.quickinbox.data.defaultSwipeControls
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadSummary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MailboxSwipeControlsTest {
    @Test
    fun defaultsMatchEachMailboxWorkflow() {
        assertEquals(SwipeControl.ToggleRead, defaultSwipeControls(MailboxKind.Inbox).startToEnd)
        assertEquals(SwipeControl.Archive, defaultSwipeControls(MailboxKind.Inbox).endToStart)
        assertEquals(SwipeControl.MoveToInbox, defaultSwipeControls(MailboxKind.Archive).endToStart)
        assertEquals(SwipeControl.Delete, defaultSwipeControls(MailboxKind.Trash).startToEnd)
        assertEquals(SwipeControl.Restore, defaultSwipeControls(MailboxKind.Trash).endToStart)
    }

    @Test
    fun destructiveAndInvalidControlsStayScoped() {
        assertTrue(SwipeControl.Trash in availableSwipeControls(MailboxKind.Inbox))
        assertFalse(SwipeControl.Delete in availableSwipeControls(MailboxKind.Inbox))
        assertFalse(SwipeControl.Archive in availableSwipeControls(MailboxKind.Trash))
        assertTrue(SwipeControl.Delete in availableSwipeControls(MailboxKind.Trash))
    }

    @Test
    fun toggleControlsResolveFromCurrentThreadState() {
        assertEquals(MailAction.Read, SwipeControl.ToggleRead.resolve(ThreadSummary(isRead = false)))
        assertEquals(MailAction.Unread, SwipeControl.ToggleRead.resolve(ThreadSummary(isRead = true)))
        assertEquals(MailAction.Star, SwipeControl.ToggleStar.resolve(ThreadSummary(isStarred = false)))
        assertEquals(MailAction.Unstar, SwipeControl.ToggleStar.resolve(ThreadSummary(isStarred = true)))
    }
}
