package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.R
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

@Composable
internal fun MailboxDrawer(
    selected: MailboxKind,
    onSelect: (MailboxKind) -> Unit,
    onSettings: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val haptics = rememberQuickInboxHaptics()
    ModalDrawerSheet(
        drawerShape = RoundedCornerShape(topEnd = 32.dp, bottomEnd = 32.dp),
        drawerContainerColor = colors.surfaceContainerLow,
        drawerTonalElevation = 0.dp
    ) {
        Column(Modifier.fillMaxHeight().padding(horizontal = 16.dp)) {
            Column(
                modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())
                    .padding(top = 16.dp, bottom = 12.dp)
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth()
                        .background(
                            Brush.linearGradient(listOf(colors.primaryContainer, colors.secondaryContainer)),
                            RoundedCornerShape(24.dp)
                        )
                        .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = colors.surface.copy(alpha = 0.8f)
                    ) {
                        Image(
                            painter = painterResource(R.drawable.ic_quickinbox),
                            contentDescription = null,
                            modifier = Modifier.padding(10.dp).size(36.dp)
                        )
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            "QuickInbox",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold,
                            color = colors.onPrimaryContainer
                        )
                        Text(
                            "Your self hosted private mailbox",
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.onPrimaryContainer
                        )
                    }
                }
                DrawerSectionLabel("Mailboxes")
                PrimaryMailboxes.forEach { kind ->
                    DrawerMailboxItem(kind, kind == selected) {
                        haptics.selectionChanged()
                        onSelect(kind)
                    }
                }
                DrawerSectionLabel("Organize")
                OverflowMailboxes.forEach { kind ->
                    DrawerMailboxItem(kind, kind == selected) {
                        haptics.selectionChanged()
                        onSelect(kind)
                    }
                }
            }
            HorizontalDivider(color = colors.outlineVariant, modifier = Modifier.padding(horizontal = 12.dp))
            NavigationDrawerItem(
                selected = false,
                onClick = { haptics.tap(); onSettings() },
                icon = { Icon(Icons.Rounded.Settings, contentDescription = null) },
                label = { Text("Settings", fontWeight = FontWeight.Medium) },
                badge = { Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = null, modifier = Modifier.size(20.dp)) },
                shape = RoundedCornerShape(18.dp),
                colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = colors.surfaceContainerLow),
                modifier = Modifier.padding(vertical = 12.dp)
            )
        }
    }
}

@Composable
private fun DrawerSectionLabel(title: String) {
    Text(
        title,
        modifier = Modifier.padding(start = 16.dp, top = 24.dp, bottom = 10.dp),
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun DrawerMailboxItem(kind: MailboxKind, selected: Boolean, onClick: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    NavigationDrawerItem(
        selected = selected,
        onClick = onClick,
        icon = {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = if (selected) colors.primary else colors.surfaceContainerHighest
            ) {
                Box(Modifier.size(36.dp), contentAlignment = Alignment.Center) {
                    Icon(
                        kind.icon,
                        contentDescription = null,
                        tint = if (selected) colors.onPrimary else colors.onSurfaceVariant,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        },
        label = { Text(kind.title, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium) },
        badge = {
            if (selected) Icon(Icons.Rounded.Check, contentDescription = null, modifier = Modifier.size(18.dp))
        },
        shape = RoundedCornerShape(18.dp),
        colors = NavigationDrawerItemDefaults.colors(
            selectedContainerColor = colors.primaryContainer,
            selectedTextColor = colors.onPrimaryContainer,
            selectedBadgeColor = colors.onPrimaryContainer,
            unselectedContainerColor = colors.surfaceContainerLow,
            unselectedTextColor = colors.onSurface
        ),
        modifier = Modifier.padding(vertical = 3.dp)
    )
}
