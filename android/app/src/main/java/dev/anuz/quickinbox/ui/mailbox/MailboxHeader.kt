package dev.anuz.quickinbox.ui.mailbox

import androidx.compose.foundation.background
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.SearchBarDefaults
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics

/** Shared mailbox identity, search, and filters for dock and drawer navigation. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MailboxHeader(
    mailbox: MailboxKind,
    searchText: String,
    unreadOnly: Boolean,
    starredOnly: Boolean,
    showUnreadFilter: Boolean,
    onSearchChange: (String) -> Unit,
    onToggleUnread: () -> Unit,
    onToggleStarred: () -> Unit,
    showNavigationMenu: Boolean,
    onOpenNavigation: () -> Unit,
    onOpenSettings: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    val searchContainer = SearchBarDefaults.colors().containerColor
    val haptics = rememberQuickInboxHaptics()
    val focusManager = LocalFocusManager.current
    val searchLabel = "Search ${mailbox.title}"
    var filtersOpen by rememberSaveable(mailbox, showNavigationMenu) { mutableStateOf(false) }
    val activeFilters = (if (showUnreadFilter && unreadOnly) 1 else 0) + (if (starredOnly) 1 else 0)

    LaunchedEffect(mailbox, showNavigationMenu) { focusManager.clearFocus() }

    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 4.dp, bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (showNavigationMenu) {
                IconButton(onClick = {
                    focusManager.clearFocus()
                    haptics.tap()
                    onOpenNavigation()
                }) {
                    Icon(Icons.Rounded.Menu, contentDescription = "Open mailboxes")
                }
            }
            Text(
                text = mailbox.title,
                modifier = Modifier.weight(1f).semantics { heading() },
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
                color = colors.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            IconButton(onClick = {
                focusManager.clearFocus()
                haptics.tap()
                onOpenSettings()
            }) {
                Icon(
                    Icons.Rounded.Settings,
                    contentDescription = "Settings",
                    tint = colors.onSurfaceVariant
                )
            }
        }
        TextField(
            value = searchText,
            onValueChange = onSearchChange,
            modifier = Modifier.fillMaxWidth().heightIn(min = SearchBarDefaults.InputFieldHeight)
                .semantics { contentDescription = searchLabel },
            textStyle = MaterialTheme.typography.bodyLarge,
            placeholder = { Text(searchLabel, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            leadingIcon = { Icon(Icons.Rounded.Search, contentDescription = null) },
            trailingIcon = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (searchText.isNotEmpty()) {
                        IconButton(onClick = { haptics.tap(); onSearchChange("") }) {
                            Icon(Icons.Rounded.Close, contentDescription = "Clear search")
                        }
                    }
                    Box {
                        IconButton(
                            onClick = {
                                focusManager.clearFocus()
                                haptics.tap()
                                filtersOpen = true
                            },
                            modifier = Modifier.padding(end = 4.dp).background(
                                if (activeFilters > 0) colors.secondaryContainer else Color.Transparent,
                                CircleShape
                            )
                        ) {
                            BadgedBox(badge = {
                                if (activeFilters > 0) {
                                    Badge { Text(activeFilters.toString()) }
                                }
                            }) {
                                Icon(
                                    Icons.Rounded.Tune,
                                    contentDescription = if (activeFilters == 0) "Filters" else "Filters, $activeFilters active",
                                    tint = if (activeFilters > 0) colors.onSecondaryContainer else colors.onSurfaceVariant
                                )
                            }
                        }
                        DropdownMenu(
                            expanded = filtersOpen,
                            onDismissRequest = { filtersOpen = false },
                            modifier = Modifier.width(256.dp),
                            shape = MaterialTheme.shapes.large
                        ) {
                            Text(
                                "Show only",
                                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                                    .semantics { heading() },
                                style = MaterialTheme.typography.titleSmall,
                                color = colors.onSurfaceVariant
                            )
                            if (showUnreadFilter) {
                                MailboxFilterOption(
                                    title = "Unread",
                                    checked = unreadOnly,
                                    onToggle = { haptics.selectionChanged(); onToggleUnread() }
                                )
                            }
                            MailboxFilterOption(
                                title = "Starred",
                                checked = starredOnly,
                                onToggle = { haptics.selectionChanged(); onToggleStarred() }
                            )
                        }
                    }
                }
            },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() }),
            shape = SearchBarDefaults.inputFieldShape,
            colors = SearchBarDefaults.inputFieldColors().copy(
                focusedContainerColor = searchContainer,
                unfocusedContainerColor = searchContainer,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent
            )
        )
    }

}

/** The whole row is one checkbox target; choosing either option keeps the menu open. */
@Composable
private fun MailboxFilterOption(
    title: String,
    checked: Boolean,
    onToggle: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
            .fillMaxWidth().heightIn(min = 48.dp)
            .clip(MaterialTheme.shapes.medium)
            .background(if (checked) colors.secondaryContainer else Color.Transparent)
            .toggleable(value = checked, role = Role.Checkbox, onValueChange = { onToggle() })
            .padding(start = 12.dp, end = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            title,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            color = if (checked) colors.onSecondaryContainer else colors.onSurface
        )
        Checkbox(checked = checked, onCheckedChange = null)
    }
}
