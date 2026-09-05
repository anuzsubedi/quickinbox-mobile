package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadSummary
import dev.anuz.quickinbox.domain.selectionReadAction
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

@Composable
internal fun SelectionHeader(
    selectedCount: Int,
    allSelected: Boolean,
    onToggleAll: () -> Unit,
    onClose: () -> Unit
) {
    val haptics = rememberQuickInboxHaptics()
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp).heightIn(min = 56.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        IconButton(onClick = { haptics.tap(); onClose() }) {
            Icon(Icons.Rounded.Close, contentDescription = "Clear selection")
        }
        Text(
            text = "$selectedCount selected",
            modifier = Modifier.weight(1f).semantics { heading() },
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
        IconToggleButton(checked = allSelected, onCheckedChange = { onToggleAll() }) {
            Icon(
                if (allSelected) Icons.Rounded.Deselect else Icons.Rounded.SelectAll,
                contentDescription = if (allSelected) "Deselect all" else "Select all loaded conversations"
            )
        }
    }
}

@Composable
internal fun SelectionDock(
    selected: List<ThreadSummary>,
    mailbox: MailboxKind,
    onAction: (MailAction) -> Unit
) {
    val readAction = selectionReadAction(selected)
    val allStarred = selected.all { it.isStarred }
    val colors = MaterialTheme.colorScheme
    Box(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 14.dp, vertical = 8.dp)) {
        Surface(
            shape = MaterialTheme.shapes.extraLarge,
            color = colors.surfaceContainerHigh,
            tonalElevation = 0.dp,
            shadowElevation = 3.dp
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (mailbox == MailboxKind.Trash) {
                    SelectionDockButton(
                        title = "Restore",
                        icon = Icons.Rounded.RestoreFromTrash,
                        modifier = Modifier.weight(1f),
                        onClick = { onAction(MailAction.Restore) }
                    )
                } else if (mailbox != MailboxKind.Drafts) {
                    SelectionDockButton(
                        title = if (mailbox == MailboxKind.Archive) "Inbox" else "Archive",
                        description = if (mailbox == MailboxKind.Archive) "Move to inbox" else "Archive",
                        icon = if (mailbox == MailboxKind.Archive) Icons.Rounded.Unarchive else Icons.Rounded.Archive,
                        modifier = Modifier.weight(1f),
                        onClick = { onAction(if (mailbox == MailboxKind.Archive) MailAction.Unarchive else MailAction.Archive) }
                    )
                }
                SelectionDockButton(
                    title = if (readAction == MailAction.Unread) "Unread" else "Read",
                    description = if (readAction == MailAction.Unread) "Mark as unread" else "Mark as read",
                    icon = if (readAction == MailAction.Unread) Icons.Rounded.MarkEmailUnread else Icons.Rounded.MarkEmailRead,
                    modifier = Modifier.weight(1f),
                    onClick = { onAction(readAction) }
                )
                SelectionDockButton(
                    title = if (allStarred) "Unstar" else "Star",
                    icon = if (allStarred) Icons.Outlined.StarOutline else Icons.Rounded.Star,
                    modifier = Modifier.weight(1f),
                    onClick = { onAction(if (allStarred) MailAction.Unstar else MailAction.Star) }
                )
                VerticalDivider(Modifier.height(32.dp), color = colors.outlineVariant)
                SelectionDockButton(
                    title = if (mailbox == MailboxKind.Trash) "Delete" else "Trash",
                    description = if (mailbox == MailboxKind.Trash) "Delete forever" else "Move to trash",
                    icon = if (mailbox == MailboxKind.Trash) Icons.Rounded.DeleteForever else Icons.Rounded.Delete,
                    modifier = Modifier.weight(1f),
                    destructive = true,
                    onClick = { onAction(if (mailbox == MailboxKind.Trash) MailAction.Delete else MailAction.Trash) }
                )
            }
        }
    }
}

@Composable
private fun SelectionDockButton(
    title: String,
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    description: String = title,
    destructive: Boolean = false
) {
    val haptics = rememberQuickInboxHaptics()
    val colors = MaterialTheme.colorScheme
    val foreground = if (destructive) colors.error else colors.onSurface
    Surface(
        onClick = { haptics.tap(); onClick() },
        shape = MaterialTheme.shapes.large,
        color = Color.Transparent,
        contentColor = foreground,
        modifier = modifier.heightIn(min = 64.dp).semantics { contentDescription = description }
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 2.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(24.dp))
            Text(
                title,
                style = MaterialTheme.typography.labelMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
