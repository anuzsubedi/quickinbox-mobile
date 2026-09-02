package dev.anuz.quickinbox.data

import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadSummary

enum class SwipeDirection {
    StartToEnd,
    EndToStart
}

enum class SwipeControl(val title: String) {
    None("None"),
    ToggleRead("Mark read / unread"),
    ToggleStar("Star / unstar"),
    Archive("Archive"),
    MoveToInbox("Move to inbox"),
    Trash("Move to trash"),
    Restore("Restore"),
    Delete("Delete permanently");

    fun resolve(thread: ThreadSummary): MailAction? = when (this) {
        None -> null
        ToggleRead -> if (thread.isRead) MailAction.Unread else MailAction.Read
        ToggleStar -> if (thread.isStarred) MailAction.Unstar else MailAction.Star
        Archive -> MailAction.Archive
        MoveToInbox -> MailAction.Unarchive
        Trash -> MailAction.Trash
        Restore -> MailAction.Restore
        Delete -> MailAction.Delete
    }
}

data class MailboxSwipeControls(
    val startToEnd: SwipeControl,
    val endToStart: SwipeControl
) {
    fun control(direction: SwipeDirection): SwipeControl = when (direction) {
        SwipeDirection.StartToEnd -> startToEnd
        SwipeDirection.EndToStart -> endToStart
    }
}

val ConfigurableSwipeMailboxes = listOf(MailboxKind.Inbox, MailboxKind.Archive, MailboxKind.Trash)

fun defaultSwipeControls(mailbox: MailboxKind): MailboxSwipeControls = when (mailbox) {
    MailboxKind.Inbox -> MailboxSwipeControls(SwipeControl.ToggleRead, SwipeControl.Archive)
    MailboxKind.Archive -> MailboxSwipeControls(SwipeControl.ToggleRead, SwipeControl.MoveToInbox)
    MailboxKind.Trash -> MailboxSwipeControls(SwipeControl.Delete, SwipeControl.Restore)
    else -> MailboxSwipeControls(SwipeControl.None, SwipeControl.Trash)
}

fun availableSwipeControls(mailbox: MailboxKind): List<SwipeControl> = when (mailbox) {
    MailboxKind.Inbox -> listOf(
        SwipeControl.None,
        SwipeControl.ToggleRead,
        SwipeControl.ToggleStar,
        SwipeControl.Archive,
        SwipeControl.Trash
    )
    MailboxKind.Archive -> listOf(
        SwipeControl.None,
        SwipeControl.ToggleRead,
        SwipeControl.ToggleStar,
        SwipeControl.MoveToInbox,
        SwipeControl.Trash
    )
    MailboxKind.Trash -> listOf(SwipeControl.None, SwipeControl.Restore, SwipeControl.Delete)
    else -> listOf(SwipeControl.None, SwipeControl.Trash)
}
