package dev.anuz.quickinbox.ui.thread

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Reply
import androidx.compose.material.icons.automirrored.outlined.ReplyAll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

/** Original reader layout: reply and forward stay at the bottom; mailbox actions live above. */
@Composable
internal fun ThreadReplyBar(enabled: Boolean, onForwardAll: (() -> Unit)?, onReply: () -> Unit) {
    val haptics = rememberQuickInboxHaptics()
    Surface(color = MaterialTheme.colorScheme.surface, tonalElevation = 0.dp) {
        Row(
            modifier = Modifier.fillMaxWidth().navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (onForwardAll != null) {
                FilledTonalButton(
                    onClick = { haptics.tap(); onForwardAll() },
                    enabled = enabled,
                    shape = MaterialTheme.shapes.large,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                        contentColor = MaterialTheme.colorScheme.onSurface
                    ),
                    modifier = Modifier.weight(1f).heightIn(min = 56.dp)
                        .semantics { contentDescription = "Forward entire conversation" }
                ) {
                    Icon(Icons.AutoMirrored.Outlined.ReplyAll, contentDescription = null, modifier = Modifier.size(20.dp).scale(scaleX = -1f, scaleY = 1f))
                    Spacer(Modifier.width(8.dp))
                    Text("Forward", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Medium)
                }
            }
            Button(
                onClick = { haptics.tap(); onReply() },
                enabled = enabled,
                shape = MaterialTheme.shapes.large,
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
                modifier = Modifier.weight(1.15f).heightIn(min = 56.dp)
            ) {
                Icon(Icons.AutoMirrored.Outlined.Reply, contentDescription = null, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Reply", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
