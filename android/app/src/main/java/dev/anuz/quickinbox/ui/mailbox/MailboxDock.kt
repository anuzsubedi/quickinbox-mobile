package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

/** Main mailbox group, shared by the dock and drawer. */
internal val PrimaryMailboxes = listOf(
    MailboxKind.Inbox,
    MailboxKind.Archive,
    MailboxKind.Sent
)

/** Organization destinations, shown directly in the dock and grouped in the drawer. */
internal val OrganizeMailboxes = MailboxKind.entries.filterNot { it in PrimaryMailboxes || it == MailboxKind.Starred }

internal val DockHeight = 80.dp
internal val DockVerticalPadding = 8.dp

/** Material navigation items in a floating dock above the system navigation area. */
@Composable
fun BottomMailboxShelf(
    current: MailboxKind,
    onSelectMailbox: (MailboxKind) -> Unit
) {
    val haptics = rememberQuickInboxHaptics()
    Box(
        modifier = Modifier.fillMaxWidth().navigationBarsPadding()
            .padding(horizontal = 14.dp, vertical = DockVerticalPadding)
    ) {
        NavigationBar(
            modifier = Modifier.fillMaxWidth().height(DockHeight).clip(RoundedCornerShape(28.dp)),
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
            tonalElevation = 0.dp,
            windowInsets = WindowInsets(0, 0, 0, 0)
        ) {
            (PrimaryMailboxes + OrganizeMailboxes).forEach { kind ->
                NavigationBarItem(
                    selected = kind == current,
                    onClick = {
                        if (kind != current) {
                            haptics.selectionChanged()
                            onSelectMailbox(kind)
                        }
                    },
                    icon = { Icon(kind.icon, contentDescription = null) },
                    label = { Text(kind.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    alwaysShowLabel = true
                )
            }

        }
    }
}
