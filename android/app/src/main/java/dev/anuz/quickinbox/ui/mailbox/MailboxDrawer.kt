package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.anuz.quickinbox.R
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.ui.components.QuickInboxWordmark
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

@Composable
internal fun MailboxDrawer(
    selected: MailboxKind,
    onSelect: (MailboxKind) -> Unit,
    onSettings: () -> Unit,
    onClose: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val haptics = rememberQuickInboxHaptics()
    ModalDrawerSheet(
        drawerContainerColor = colors.surfaceContainerLow,
        drawerTonalElevation = 0.dp
    ) {
        Column(Modifier.fillMaxHeight()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(start = 24.dp, end = 12.dp)
                    .padding(top = 12.dp, bottom = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Image(
                    painter = painterResource(R.drawable.ic_quickinbox),
                    contentDescription = null,
                    modifier = Modifier.size(32.dp)
                )
                QuickInboxWordmark(
                    modifier = Modifier.weight(1f),
                    fontSize = 22.sp,
                    color = colors.onSurface,
                    overflow = TextOverflow.Ellipsis
                )
                IconButton(onClick = { haptics.tap(); onClose() }) {
                    Icon(Icons.Rounded.Close, contentDescription = "Close mailboxes")
                }
            }
            Column(
                modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())
                    .padding(horizontal = 12.dp).padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    "Mailboxes",
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                        .semantics { heading() },
                    style = MaterialTheme.typography.titleSmall,
                    color = colors.onSurfaceVariant
                )
                (PrimaryMailboxes + OrganizeMailboxes).forEach { kind ->
                    NavigationDrawerItem(
                        selected = kind == selected,
                        onClick = {
                            if (kind != selected) haptics.selectionChanged() else haptics.tap()
                            onSelect(kind)
                        },
                        icon = { Icon(kind.icon, contentDescription = null) },
                        label = {
                            Text(
                                kind.title,
                                fontWeight = if (kind == selected) FontWeight.SemiBold else FontWeight.Medium
                            )
                        },
                        colors = NavigationDrawerItemDefaults.colors(
                            unselectedContainerColor = colors.surfaceContainerLow,
                            selectedContainerColor = colors.secondaryContainer,
                            selectedIconColor = colors.onSecondaryContainer,
                            selectedTextColor = colors.onSecondaryContainer,
                            unselectedIconColor = colors.onSurfaceVariant,
                            unselectedTextColor = colors.onSurfaceVariant
                        )
                    )
                }
            }
            HorizontalDivider(
                color = colors.outlineVariant,
                modifier = Modifier.padding(horizontal = 28.dp)
            )
            NavigationDrawerItem(
                selected = false,
                onClick = { haptics.tap(); onSettings() },
                icon = { Icon(Icons.Rounded.Settings, contentDescription = null) },
                label = { Text("Settings") },
                colors = NavigationDrawerItemDefaults.colors(
                    unselectedContainerColor = colors.surfaceContainerLow,
                    unselectedIconColor = colors.onSurfaceVariant,
                    unselectedTextColor = colors.onSurfaceVariant
                ),
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 12.dp)
            )
        }
    }
}
