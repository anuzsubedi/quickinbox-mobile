package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadSummary
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

@Composable
internal fun SelectionHeader(selectedCount: Int, onClose: () -> Unit) {
    val haptics = rememberQuickInboxHaptics()
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "$selectedCount selected",
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Surface(
            onClick = { haptics.tap(); onClose() },
            modifier = Modifier.size(48.dp),
            shape = RoundedCornerShape(16.dp),
            color = MaterialTheme.colorScheme.surfaceContainerHighest,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, contentDescription = "Close selection")
            }
        }
    }
}

@Composable
internal fun SelectionDock(
    selected: List<ThreadSummary>,
    allSelected: Boolean,
    mailbox: MailboxKind,
    onToggleAll: () -> Unit,
    onAction: (MailAction) -> Unit
) {
    val readAction = if (selected.all { it.isRead }) MailAction.Unread else MailAction.Read
    val allStarred = selected.all { it.isStarred }
    Box(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 14.dp, vertical = 8.dp)) {
        Surface(
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surface,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            shadowElevation = 8.dp
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                    .padding(horizontal = 8.dp, vertical = 7.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (mailbox != MailboxKind.Drafts && mailbox != MailboxKind.Trash) {
                    SelectionDockButton(
                        title = if (mailbox == MailboxKind.Archive) "Inbox" else "Archive",
                        icon = if (mailbox == MailboxKind.Archive) Icons.Rounded.Unarchive else Icons.Rounded.Archive,
                        onClick = { onAction(if (mailbox == MailboxKind.Archive) MailAction.Unarchive else MailAction.Archive) }
                    )
                }
                SelectionDockButton(
                    title = if (mailbox == MailboxKind.Trash) "Restore" else "Trash",
                    icon = if (mailbox == MailboxKind.Trash) Icons.Rounded.RestoreFromTrash else Icons.Rounded.Delete,
                    tint = if (mailbox == MailboxKind.Trash) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    onClick = { onAction(if (mailbox == MailboxKind.Trash) MailAction.Restore else MailAction.Trash) }
                )
                SelectionDockButton(
                    title = if (readAction == MailAction.Unread) "Unread" else "Read",
                    icon = if (readAction == MailAction.Unread) Icons.Rounded.MarkEmailUnread else Icons.Rounded.MarkEmailRead,
                    onClick = { onAction(readAction) }
                )
                SelectionDockButton(
                    title = if (allStarred) "Unstar" else "Star",
                    icon = if (allStarred) Icons.Outlined.StarOutline else Icons.Rounded.Star,
                    onClick = { onAction(if (allStarred) MailAction.Unstar else MailAction.Star) }
                )
                SelectionDockButton(
                    title = if (allSelected) "Deselect" else "Select all",
                    icon = if (allSelected) Icons.Rounded.Deselect else Icons.Rounded.SelectAll,
                    onClick = onToggleAll
                )
                if (mailbox == MailboxKind.Trash) {
                    SelectionDockButton(
                        title = "Delete forever",
                        icon = Icons.Rounded.DeleteForever,
                        tint = MaterialTheme.colorScheme.error,
                        onClick = { onAction(MailAction.Delete) }
                    )
                }
            }
        }
    }
}

@Composable
private fun SelectionDockButton(
    title: String,
    icon: ImageVector,
    onClick: () -> Unit,
    tint: Color = MaterialTheme.colorScheme.primary
) {
    val haptics = rememberQuickInboxHaptics()
    Surface(
        onClick = { haptics.tap(); onClick() },
        shape = RoundedCornerShape(18.dp),
        color = Color.Transparent,
        modifier = Modifier.widthIn(min = 48.dp).heightIn(min = 56.dp)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(21.dp))
            Spacer(Modifier.height(2.dp))
            Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
