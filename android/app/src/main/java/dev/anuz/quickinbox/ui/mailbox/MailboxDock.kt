package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.ui.components.Pressable
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics
import dev.anuz.quickinbox.ui.theme.LocalQuickInboxDarkTheme

/** Bottom nav shows these directly; everything else lives behind "More". */
internal val PrimaryMailboxes = listOf(
    MailboxKind.Inbox,
    MailboxKind.Sent,
    MailboxKind.Drafts
)

/** Remaining mailboxes, reachable through the "More" sheet. */
internal val OverflowMailboxes = MailboxKind.entries.filterNot { it in PrimaryMailboxes || it == MailboxKind.Starred }

internal val DockHeight = 64.dp
private val DockShape = RoundedCornerShape(24.dp)
private val IndicatorShape = RoundedCornerShape(16.dp)

/**
 * A floating, ruled dock rather than a stock Material bottom navigation bar — it reads as
 * a distinct object resting above the content instead of chrome bolted to the screen edge.
 * Only shown for primary mailboxes; overflow mailboxes (Archive, Trash, ...) hide this
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
            .padding(horizontal = 20.dp, vertical = 14.dp)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .height(DockHeight),
            shape = DockShape,
            color = if (LocalQuickInboxDarkTheme.current) MaterialTheme.colorScheme.surfaceContainerLow
            else MaterialTheme.colorScheme.surfaceContainerLowest,
            shadowElevation = 0.dp,
            tonalElevation = 0.dp
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 6.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                PrimaryMailboxes.forEach { kind ->
                    DockItem(
                        title = kind.title,
                        icon = kind.icon,
                        selected = kind == current,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                        onClick = {
                            if (kind != current) {
                                haptics.selectionChanged()
                                onSelectMailbox(kind)
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
        targetValue = if (selected) MaterialTheme.colorScheme.onSecondaryContainer
        else MaterialTheme.colorScheme.onSurfaceVariant,
        label = "dock-item-content"
    )
    // Fading to Color.Transparent would lerp through its black RGB and flash the pill dark, so
    // the cleared state keeps the indicator hue and only drops its alpha.
    val indicator = MaterialTheme.colorScheme.secondaryContainer
    val indicatorColor by animateColorAsState(
        targetValue = if (selected) indicator else indicator.copy(alpha = 0f),
        label = "dock-item-indicator"
    )
    val scale by animateFloatAsState(
        targetValue = if (selected) 1.14f else 1f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = 480f),
        label = "dock-item-scale"
    )

    Pressable(
        onClick = onClick,
        role = Role.Tab,
        onClickLabel = title,
        selectedState = selected,
        stateDescription = if (selected) "Selected" else "Not selected",
        shape = RoundedCornerShape(18.dp),
        modifier = modifier
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 6.dp, vertical = 4.dp)
                .clip(IndicatorShape)
                .background(indicatorColor),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                icon,
                contentDescription = if (selected) null else title,
                tint = contentColor,
                modifier = Modifier
                    .size(22.dp)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    }
            )
        }
    }
}
