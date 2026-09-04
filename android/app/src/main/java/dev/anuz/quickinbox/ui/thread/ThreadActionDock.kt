package dev.anuz.quickinbox.ui.thread

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Reply
import androidx.compose.material.icons.automirrored.outlined.ReplyAll
import androidx.compose.material.icons.automirrored.rounded.Forward
import androidx.compose.material.icons.rounded.Archive
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.RestoreFromTrash
import androidx.compose.material.icons.rounded.Unarchive
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

@Composable
internal fun ThreadActionDock(
    isArchived: Boolean,
    isTrashed: Boolean,
    enabled: Boolean,
    onReply: () -> Unit,
    onReplyAll: () -> Unit,
    onForward: () -> Unit,
    onArchive: () -> Unit,
    onTrash: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 14.dp, vertical = 8.dp)) {
        Surface(
            shape = RoundedCornerShape(percent = 50),
            color = MaterialTheme.colorScheme.surface,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            shadowElevation = 0.dp,
            tonalElevation = 0.dp
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                    .padding(horizontal = 8.dp, vertical = 7.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                ReaderDockButton("Reply", Icons.AutoMirrored.Outlined.Reply, enabled, onReply)
                ReaderDockButton("Reply all", Icons.AutoMirrored.Outlined.ReplyAll, enabled, onReplyAll)
                if (!isTrashed) {
                    ReaderDockButton("Forward", Icons.AutoMirrored.Rounded.Forward, enabled, onForward)
                }
                VerticalDivider(
                    modifier = Modifier.height(28.dp).padding(horizontal = 4.dp),
                    thickness = 1.dp,
                    color = MaterialTheme.colorScheme.outlineVariant
                )
                if (!isTrashed) {
                    ReaderDockButton(
                        if (isArchived) "Inbox" else "Archive",
                        if (isArchived) Icons.Rounded.Unarchive else Icons.Rounded.Archive,
                        enabled, onArchive
                    )
                }
                ReaderDockButton(
                    if (isTrashed) "Restore" else "Trash",
                    if (isTrashed) Icons.Rounded.RestoreFromTrash else Icons.Rounded.Delete,
                    enabled, onTrash,
                    tint = if (isTrashed) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

@Composable
private fun ReaderDockButton(
    title: String,
    icon: ImageVector,
    enabled: Boolean,
    onClick: () -> Unit,
    tint: Color = MaterialTheme.colorScheme.primary
) {
    val haptics = rememberQuickInboxHaptics()
    Surface(
        onClick = { haptics.tap(); onClick() },
        enabled = enabled,
        shape = RoundedCornerShape(18.dp),
        color = Color.Transparent,
        modifier = Modifier.widthIn(min = 48.dp).heightIn(min = 56.dp)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(21.dp))
            Spacer(Modifier.height(2.dp))
            Text(title, style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
