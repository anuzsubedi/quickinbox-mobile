package dev.anuz.quickinbox.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import dev.anuz.quickinbox.data.SwipeControl
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.ui.components.swipeicons.*

val SwipeControl.fallbackIcon: ImageVector
    get() = when (this) {
        SwipeControl.None -> Icons.Rounded.Block
        SwipeControl.ToggleRead -> Icons.Rounded.MarkEmailRead
        SwipeControl.ToggleStar -> Icons.Rounded.Star
        SwipeControl.Archive -> Icons.Rounded.Archive
        SwipeControl.MoveToInbox -> Icons.Rounded.Unarchive
        SwipeControl.Trash, SwipeControl.Delete -> Icons.Rounded.Delete
        SwipeControl.Restore -> Icons.Rounded.RestoreFromTrash
    }

@Composable
fun SwipeControlIcon(control: SwipeControl, progress: Float, color: Color, modifier: Modifier = Modifier, resolvedAction: MailAction? = null) {
    when (control) {
        SwipeControl.None -> Icon(control.fallbackIcon, control.title, modifier, tint = color)
        SwipeControl.ToggleRead -> if (resolvedAction == MailAction.Unread) UnreadSwipeIcon(progress, color, modifier) else ReadSwipeIcon(progress, color, modifier)
        SwipeControl.ToggleStar -> if (resolvedAction == MailAction.Unstar) UnstarSwipeIcon(progress, color, modifier) else StarSwipeIcon(progress, color, modifier)
        SwipeControl.Archive -> ArchiveSwipeIcon(progress, color, modifier)
        SwipeControl.MoveToInbox -> InboxSwipeIcon(progress, color, modifier)
        SwipeControl.Trash -> TrashSwipeIcon(progress, color, modifier)
        SwipeControl.Delete -> DeleteSwipeIcon(progress, color, modifier)
        SwipeControl.Restore -> RestoreSwipeIcon(progress, color, modifier)
    }
}
