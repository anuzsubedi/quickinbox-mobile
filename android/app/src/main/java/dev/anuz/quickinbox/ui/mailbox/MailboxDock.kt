package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.ui.components.Pressable
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics
import dev.anuz.quickinbox.ui.theme.LocalQuickInboxDarkTheme

/** Bottom nav shows these directly; everything else lives behind "More". */
internal val PrimaryMailboxes = listOf(
    MailboxKind.Inbox,
    MailboxKind.Archive,
    MailboxKind.Sent
)

/** Remaining mailboxes, reachable through the "More" sheet. */
internal val OverflowMailboxes = MailboxKind.entries.filterNot { it in PrimaryMailboxes || it == MailboxKind.Starred }

internal val DockHeight = 70.dp
internal val DockVerticalPadding = 8.dp
private val DockShape = RoundedCornerShape(24.dp)
private val IndicatorShape = RoundedCornerShape(17.dp)

/**
 * A floating, ruled dock rather than a stock Material bottom navigation bar — it reads as
 * a distinct object resting above the content instead of chrome bolted to the screen edge.
 * Only shown for primary mailboxes; overflow mailboxes (Drafts, Trash) hide this
 * entirely and rely on the corner FAB (now a close button) to get back
 * (see [dev.anuz.quickinbox.ui.mailbox.MailboxScreen]).
 */
@Composable
fun BottomMailboxShelf(
    current: MailboxKind,
    onSelectMailbox: (MailboxKind) -> Unit,
    moreExpanded: Boolean,
    onToggleMore: () -> Unit
) {
    val haptics = rememberQuickInboxHaptics()

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 14.dp, vertical = DockVerticalPadding)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .height(DockHeight),
            shape = DockShape,
            color = if (LocalQuickInboxDarkTheme.current) MaterialTheme.colorScheme.surfaceContainerLow
            else MaterialTheme.colorScheme.surfaceContainerLowest,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            shadowElevation = 0.dp,
            tonalElevation = 0.dp
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 8.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                PrimaryMailboxes.forEach { kind ->
                    DockItem(
                        title = kind.title,
                        icon = kind.icon,
                        selected = kind == current && !moreExpanded,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                        onClick = {
                            if (kind != current || moreExpanded) {
                                haptics.selectionChanged()
                                if (moreExpanded) onToggleMore()
                                if (kind != current) onSelectMailbox(kind)
                            }
                        }
                    )
                }
                DockItem(
                    title = "More",
                    icon = Icons.Rounded.MoreHoriz,
                    selected = moreExpanded,
                    modifier = Modifier.weight(1f).fillMaxHeight(),
                    onClick = {
                        haptics.tap()
                        onToggleMore()
                    }
                )
            }
        }
    }
}

@Composable
private fun DockItem(
    title: String,
    icon: ImageVector,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val contentColor by animateColorAsState(
        targetValue = if (selected) MaterialTheme.colorScheme.primary
        else MaterialTheme.colorScheme.onSurfaceVariant,
        label = "dock-item-content"
    )
    // Fading to Color.Transparent would lerp through its black RGB and flash the pill dark, so
    // the cleared state keeps the indicator hue and only drops its alpha.
    val indicator = MaterialTheme.colorScheme.primaryContainer
    val indicatorColor by animateColorAsState(
        targetValue = if (selected) indicator else indicator.copy(alpha = 0f),
        label = "dock-item-indicator"
    )
    Pressable(
        onClick = onClick,
        role = Role.Tab,
        onClickLabel = title,
        selectedState = selected,
        stateDescription = if (selected) "Selected" else "Not selected",
        shape = IndicatorShape,
        modifier = modifier
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .clip(IndicatorShape)
                .background(indicatorColor),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically)
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(26.dp)
            )
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall.copy(
                    fontSize = 9.sp,
                    fontWeight = FontWeight(750)
                ),
                color = contentColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
