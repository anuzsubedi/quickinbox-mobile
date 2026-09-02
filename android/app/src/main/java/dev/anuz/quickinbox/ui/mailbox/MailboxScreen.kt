package dev.anuz.quickinbox.ui.mailbox

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.outlined.MarkEmailUnread
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.rounded.Archive
import androidx.compose.material.icons.rounded.AttachFile
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Clear
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Drafts
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.MarkEmailRead
import androidx.compose.material.icons.rounded.MarkEmailUnread
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.RestoreFromTrash
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Unarchive
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FloatingActionButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.R
import dev.anuz.quickinbox.data.MailboxNavigationStyle
import dev.anuz.quickinbox.data.MailboxSwipeControls
import dev.anuz.quickinbox.data.SwipeControl
import dev.anuz.quickinbox.data.defaultSwipeControls
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadSummary
import dev.anuz.quickinbox.domain.mailboxRelativeLabel
import dev.anuz.quickinbox.ui.components.Pressable
import dev.anuz.quickinbox.ui.components.SenderTile
import dev.anuz.quickinbox.ui.components.SwipeControlIcon
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics
import dev.anuz.quickinbox.ui.theme.LocalQuickInboxDarkTheme
import dev.anuz.quickinbox.ui.theme.QuickInboxMotion
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun MailboxScreen(
    state: MailboxUiState,
    navigationStyle: MailboxNavigationStyle,
    swipeControls: Map<MailboxKind, MailboxSwipeControls>,
    onSelectMailbox: (MailboxKind) -> Unit,
    onSearchChange: (String) -> Unit,
    onToggleUnread: () -> Unit,
    onRefresh: () -> Unit,
    onLoadNext: () -> Unit,
    onOpenThread: (ThreadSummary) -> Unit,
    onCompose: (draftId: String?) -> Unit,
    onOpenSettings: () -> Unit,
    onAction: (MailAction, List<ThreadSummary>) -> Unit,
    onDismissError: () -> Unit
) {
    val snackbar = remember { SnackbarHostState() }
    val listState = rememberLazyListState()
    val haptics = rememberQuickInboxHaptics()
    val drawerState = androidx.compose.material3.rememberDrawerState(androidx.compose.material3.DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var selectedIds by remember { mutableStateOf(emptySet<String>()) }
    var actionTargets by remember { mutableStateOf<List<ThreadSummary>?>(null) }
    var pendingSwipeDelete by remember { mutableStateOf<ThreadSummary?>(null) }
    var lastPrimaryMailbox by remember { mutableStateOf(MailboxKind.Inbox) }
    var moreExpanded by remember { mutableStateOf(false) }
    val selectedThreads = state.threads.filter { it.id in selectedIds }
    val selectionActive = selectedThreads.isNotEmpty()

    BackHandler(enabled = selectionActive) { selectedIds = emptySet() }
    LaunchedEffect(state.mailbox) {
        selectedIds = emptySet()
        moreExpanded = false
        if (state.mailbox in PrimaryMailboxes) lastPrimaryMailbox = state.mailbox
    }
    val isNativeNavigation = navigationStyle == MailboxNavigationStyle.Native
    BackHandler(enabled = isNativeNavigation && !selectionActive && state.mailbox in OverflowMailboxes) {
        onSelectMailbox(lastPrimaryMailbox)
    }
    BackHandler(enabled = isNativeNavigation && moreExpanded) { moreExpanded = false }
    LaunchedEffect(state.actionError, state.refreshError) {
        val message = state.actionError ?: state.refreshError
        if (message != null) {
            snackbar.showSnackbar(message)
            onDismissError()
        }
    }
    LaunchedEffect(listState, state.threads.size) {
        snapshotFlow {
            val info = listState.layoutInfo
            val last = info.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= info.totalItemsCount - 3
        }.distinctUntilChanged().collect { if (it) onLoadNext() }
    }

    fun perform(action: MailAction, targets: List<ThreadSummary>) {
        if (targets.isEmpty()) return
        onAction(action, targets)
        selectedIds = emptySet()
        actionTargets = null
    }

    val inOverflow = isNativeNavigation && state.mailbox in OverflowMailboxes

    val mailboxContent: @Composable () -> Unit = {
    Scaffold(
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            if (!isNativeNavigation && !selectionActive) {
                ExtendedFloatingActionButton(
                    onClick = { onCompose(null) },
                    icon = { Icon(Icons.Rounded.Edit, contentDescription = null) },
                    text = { Text("Compose") },
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        },
        bottomBar = {
            AnimatedVisibility(
                visible = isNativeNavigation && !selectionActive && !inOverflow,
                enter = fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Decelerate)) +
                    expandVertically(
                        tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Decelerate),
                        expandFrom = Alignment.Bottom
                    ),
                exit = fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) +
                    shrinkVertically(
                        tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate),
                        shrinkTowards = Alignment.Bottom
                    )
            ) {
                BottomMailboxShelf(
                    current = state.mailbox,
                    onSelectMailbox = onSelectMailbox,
                    moreExpanded = moreExpanded,
                    onToggleMore = { moreExpanded = !moreExpanded }
                )
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize()) {
        PullToRefreshBox(
            isRefreshing = state.isRefreshing,
            onRefresh = onRefresh,
            modifier = Modifier.fillMaxSize().padding(padding)
        ) {
            Column(Modifier.fillMaxSize()) {
                AnimatedContent(
                    targetState = selectionActive,
                    transitionSpec = {
                        (fadeIn(tween(180)) + slideInVertically(tween(220)) { -it / 4 }) togetherWith
                            (fadeOut(tween(120)) + slideOutVertically(tween(180)) { -it / 4 }) using
                            SizeTransform(clip = false)
                    },
                    label = "mailbox-header"
                ) { selecting ->
                    if (selecting) {
                        SelectionHeader(
                            selected = selectedThreads,
                            allThreads = state.threads,
                            mailbox = state.mailbox,
                            onClose = { selectedIds = emptySet() },
                            onToggleAll = {
                                haptics.selectionChanged()
                                selectedIds = if (selectedIds.size == state.threads.size) emptySet()
                                else state.threads.mapTo(mutableSetOf()) { it.id }
                            },
                            onAction = { perform(it, selectedThreads) },
                            onMore = { actionTargets = selectedThreads }
                        )
                    } else {
                        MailboxControls(
                            mailbox = state.mailbox,
                            searchText = state.searchText,
                            unreadOnly = state.unreadOnly,
                            showUnreadFilter = state.mailbox == MailboxKind.Inbox,
                            onSearchChange = onSearchChange,
                            onToggleUnread = onToggleUnread,
                            showNavigationMenu = !isNativeNavigation,
                            onOpenNavigation = { scope.launch { drawerState.open() } },
                            onOpenSettings = onOpenSettings
                        )
                    }
                }
                if (state.isShowingCachedData) {
                    Text(
                        "Showing saved mail · Pull to refresh",
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                when {
                    state.isInitialLoading -> LoadingState()
                    state.initialError != null && state.threads.isEmpty() -> ErrorState(state.initialError, onRefresh)
                    state.threads.isEmpty() -> EmptyState(state.mailbox)
                    else -> LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(bottom = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        itemsIndexed(state.threads, key = { _, thread -> thread.id }) { index, thread ->
                            SwipeableMailThreadItem(
                                thread = thread,
                                mailbox = state.mailbox,
                                controls = swipeControls[state.mailbox] ?: defaultSwipeControls(state.mailbox),
                                first = index == 0,
                                last = index == state.threads.lastIndex,
                                selected = thread.id in selectedIds,
                                selectionActive = selectionActive,
                                working = thread.id in state.mutatingIds,
                                onClick = {
                                    if (selectionActive) {
                                        haptics.selectionChanged()
                                        selectedIds = selectedIds.toggling(thread.id)
                                    } else if (thread.isDraft) {
                                        onCompose(thread.latestId)
                                    } else {
                                        onOpenThread(thread)
                                    }
                                },
                                onLongClick = {
                                    haptics.longPress()
                                    selectedIds = selectedIds.toggling(thread.id)
                                },
                                onSwipeAction = {
                                    haptics.confirm()
                                    if (it == MailAction.Delete) {
                                        pendingSwipeDelete = thread
                                    } else {
                                        perform(it, listOf(thread))
                                    }
                                },
                                onStar = {
                                    perform(
                                        if (thread.isStarred) MailAction.Unstar else MailAction.Star,
                                        listOf(thread)
                                    )
                                }
                            )
                        }
                        if (state.isAppending) {
                            item {
                                Box(Modifier.fillMaxWidth().padding(20.dp), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
                                }
                            }
                        }
                    }
                }
            }
        }

        if (isNativeNavigation && !selectionActive) {
            val fabBottomInset by animateDpAsState(
                targetValue = if (inOverflow) 16.dp else DockHeight + 28.dp + 16.dp,
                animationSpec = tween(
                    if (inOverflow) QuickInboxMotion.DurationShort else QuickInboxMotion.DurationMedium,
                    easing = QuickInboxMotion.Decelerate
                ),
                label = "corner-fab-inset"
            )
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .navigationBarsPadding()
                    .padding(start = 16.dp, end = 16.dp, bottom = fabBottomInset)
            ) {
                AnimatedContent(
                    targetState = when {
                        moreExpanded -> CornerFabMode.Overflow
                        inOverflow -> CornerFabMode.Close
                        else -> CornerFabMode.Compose
                    },
                    transitionSpec = {
                        (fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Emphasized)) +
                            scaleIn(
                                tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Emphasized),
                                initialScale = 0.6f
                            )).togetherWith(
                            fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) +
                                scaleOut(
                                    tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate),
                                    targetScale = 0.6f
                                )
                        )
                    },
                    label = "corner-fab-content"
                ) { mode ->
                    // A shadow ignores the fade, so an outgoing button keeps casting one at full
                    // strength over the incoming button. Dropping it the instant a button starts
                    // leaving keeps the shadow from doubling, while the arriving button carries
                    // its own from the first frame.
                    val elevation = if (transition.targetState == EnterExitState.Visible) {
                        FabElevation
                    } else {
                        0.dp
                    }
                    when (mode) {
                        CornerFabMode.Compose -> ComposeFab(
                            elevation = elevation,
                            onClick = { onCompose(null) }
                        )
                        CornerFabMode.Overflow -> OverflowOptionsFab(
                            elevation = elevation,
                            onSelect = { kind ->
                                moreExpanded = false
                                onSelectMailbox(kind)
                            }
                        )
                        CornerFabMode.Close -> CloseOverflowFab(
                            elevation = elevation,
                            onClick = { onSelectMailbox(lastPrimaryMailbox) }
                        )
                    }
                }
            }
        }
        }
    }
    }

    if (isNativeNavigation) {
        mailboxContent()
    } else {
        ModalNavigationDrawer(
            drawerState = drawerState,
            gesturesEnabled = !selectionActive,
            drawerContent = {
                LegacyMailboxDrawer(
                    selected = state.mailbox,
                    onSelect = { kind ->
                        onSelectMailbox(kind)
                        scope.launch { drawerState.close() }
                    },
                    onSettings = {
                        scope.launch {
                            drawerState.close()
                            onOpenSettings()
                        }
                    }
                )
            },
            content = { mailboxContent() }
        )
    }

    actionTargets?.let { targets ->
        ConversationActionsSheet(
            targets = targets,
            mailbox = state.mailbox,
            onDismiss = { actionTargets = null },
            onAction = { perform(it, targets) }
        )
    }
    pendingSwipeDelete?.let { thread ->
        AlertDialog(
            onDismissRequest = { pendingSwipeDelete = null },
            icon = { Icon(Icons.Rounded.Delete, contentDescription = null) },
            title = { Text("Delete forever?") },
            text = { Text("This conversation will be permanently deleted. This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    pendingSwipeDelete = null
                    perform(MailAction.Delete, listOf(thread))
                }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingSwipeDelete = null }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun LegacyMailboxDrawer(
    selected: MailboxKind,
    onSelect: (MailboxKind) -> Unit,
    onSettings: () -> Unit
) {
    ModalDrawerSheet {
        Column(Modifier.fillMaxHeight().padding(vertical = 12.dp)) {
            Row(
                modifier = Modifier.padding(horizontal = 28.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Image(
                    painter = painterResource(R.drawable.ic_quickinbox),
                    contentDescription = null,
                    modifier = Modifier.size(40.dp)
                )
                Spacer(Modifier.width(10.dp))
                Text("QuickInbox", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            }
            Text(
                "Mailboxes",
                modifier = Modifier.padding(horizontal = 28.dp, vertical = 8.dp),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            MailboxKind.entries.forEach { kind ->
                NavigationDrawerItem(
                    selected = kind == selected,
                    onClick = { onSelect(kind) },
                    icon = { Icon(kind.icon, contentDescription = null) },
                    label = { Text(kind.title) },
                    modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding)
                )
            }
            Spacer(Modifier.weight(1f))
            HorizontalDivider(Modifier.padding(horizontal = 28.dp, vertical = 8.dp))
            NavigationDrawerItem(
                selected = false,
                onClick = onSettings,
                icon = { Icon(Icons.Rounded.Settings, contentDescription = null) },
                label = { Text("Settings") },
                modifier = Modifier.padding(NavigationDrawerItemDefaults.ItemPadding)
            )
        }
    }
}

private enum class CornerFabMode { Compose, Overflow, Close }

/** Resting shadow for every corner FAB state. */
private val FabElevation = 2.dp

@Composable
private fun flatFabElevation(elevation: Dp) = FloatingActionButtonDefaults.elevation(
    defaultElevation = elevation,
    pressedElevation = elevation,
    focusedElevation = elevation,
    hoveredElevation = elevation
)

@Composable
private fun ComposeFab(elevation: Dp, onClick: () -> Unit) {
    val haptics = rememberQuickInboxHaptics()
    ExtendedFloatingActionButton(
        onClick = {
            haptics.tap()
            onClick()
        },
        modifier = Modifier.height(48.dp),
        containerColor = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        shape = RoundedCornerShape(16.dp),
        elevation = flatFabElevation(elevation),
        icon = {
            Icon(
                Icons.Rounded.Edit,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
        },
        text = {
            Text(
                "Compose",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold
            )
        }
    )
}

/**
 * Occupies the corner FAB slot while viewing an overflow mailbox (Archive, Trash, ...) —
 * the same spot and color as Compose, just swapped to a close affordance so leaving the
 * mailbox reads as dismissing it rather than a separate, disconnected control.
 */
@Composable
private fun CloseOverflowFab(elevation: Dp, onClick: () -> Unit) {
    val haptics = rememberQuickInboxHaptics()
    FloatingActionButton(
        onClick = {
            haptics.tap()
            onClick()
        },
        containerColor = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        shape = RoundedCornerShape(16.dp),
        elevation = flatFabElevation(elevation)
    ) {
        Icon(Icons.Rounded.Close, contentDescription = "Close, back to mailboxes")
    }
}

/**
 * Replaces the Compose FAB in place while the More menu is open. Overflow mailboxes render
 * as small elevated pills stacked where the FAB was, so opening/closing More reads as one
 * continuous morph rather than two unrelated floating elements competing for the corner.
 */
@Composable
private fun OverflowOptionsFab(elevation: Dp, onSelect: (MailboxKind) -> Unit) {
    val haptics = rememberQuickInboxHaptics()
    Column(
        horizontalAlignment = Alignment.End,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        OverflowMailboxes.forEach { kind ->
            OverflowOptionPill(
                title = kind.title,
                icon = kind.icon,
                elevation = elevation,
                onClick = {
                    haptics.selectionChanged()
                    onSelect(kind)
                }
            )
        }
    }
}

@Composable
private fun OverflowOptionPill(
    title: String,
    icon: ImageVector,
    elevation: Dp,
    onClick: () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        shadowElevation = elevation,
        onClick = onClick
    ) {
        Row(
            modifier = Modifier
                .heightIn(min = 48.dp)
                .padding(horizontal = 18.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.width(10.dp))
            Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
private fun MailboxControls(
    mailbox: MailboxKind,
    searchText: String,
    unreadOnly: Boolean,
    showUnreadFilter: Boolean,
    onSearchChange: (String) -> Unit,
    onToggleUnread: () -> Unit,
    showNavigationMenu: Boolean,
    onOpenNavigation: () -> Unit,
    onOpenSettings: () -> Unit
) {
    val searchContainer = if (LocalQuickInboxDarkTheme.current) MaterialTheme.colorScheme.surfaceContainerHighest
    else MaterialTheme.colorScheme.surfaceContainerLowest
    Column(
        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (showNavigationMenu) {
                IconButton(onClick = onOpenNavigation) {
                    Icon(Icons.Rounded.Menu, contentDescription = "Open mailboxes")
                }
                Spacer(Modifier.width(4.dp))
            }
            TextField(
                value = searchText,
                onValueChange = onSearchChange,
                modifier = Modifier.weight(1f).heightIn(min = 48.dp),
                textStyle = MaterialTheme.typography.bodyLarge.copy(textAlign = TextAlign.Center),
                placeholder = {
                    Text(
                        "Search in mail",
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center
                    )
                },
                trailingIcon = if (searchText.isNotEmpty()) {
                    {
                        IconButton(onClick = { onSearchChange("") }) {
                            Icon(Icons.Rounded.Clear, contentDescription = "Clear search")
                        }
                    }
                } else null,
                singleLine = true,
                shape = CircleShape,
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = searchContainer,
                    unfocusedContainerColor = searchContainer,
                    disabledContainerColor = searchContainer,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    disabledIndicatorColor = Color.Transparent
                )
            )
            Spacer(Modifier.width(8.dp))
            SettingsButton(onClick = onOpenSettings)
        }
        Row(
            modifier = Modifier
                .padding(start = 8.dp)
                .heightIn(min = 36.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = mailbox.title,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.weight(1f))
            if (showUnreadFilter) {
                UnreadToggle(
                    selected = unreadOnly,
                    onClick = onToggleUnread
                )
            }
        }
    }
}

@Composable
private fun SettingsButton(onClick: () -> Unit) {
    Pressable(
        onClick = onClick,
        role = Role.Button,
        onClickLabel = "Settings",
        shape = CircleShape,
        modifier = Modifier.size(44.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.surfaceContainerHigh),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Rounded.Settings,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}

@Composable
private fun UnreadToggle(selected: Boolean, onClick: () -> Unit) {
    val containerColor by animateColorAsState(
        targetValue = if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
        label = "unread-toggle-container"
    )
    val contentColor by animateColorAsState(
        targetValue = if (selected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant,
        label = "unread-toggle-content"
    )

    Pressable(
        onClick = onClick,
        role = Role.Checkbox,
        onClickLabel = "Unread only",
        checkedState = selected,
        stateDescription = if (selected) "On" else "Off",
        shape = CircleShape,
        modifier = Modifier.size(36.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(containerColor),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                if (selected) Icons.Rounded.MarkEmailUnread else Icons.Outlined.MarkEmailUnread,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun SelectionHeader(
    selected: List<ThreadSummary>,
    allThreads: List<ThreadSummary>,
    mailbox: MailboxKind,
    onClose: () -> Unit,
    onToggleAll: () -> Unit,
    onAction: (MailAction) -> Unit,
    onMore: () -> Unit
) {
    val allRead = selected.all { it.isRead }
    val allSelected = selected.size == allThreads.size && allThreads.isNotEmpty()
    Column(Modifier.background(MaterialTheme.colorScheme.surfaceContainer)) {
        TopAppBar(
            navigationIcon = {
                IconButton(onClick = onClose) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Clear selection") }
            },
            title = { Text(selected.size.toString(), fontWeight = FontWeight.SemiBold) },
            actions = {
                when (mailbox) {
                    MailboxKind.Archive -> IconButton(onClick = { onAction(MailAction.Unarchive) }) {
                        Icon(Icons.Rounded.Unarchive, contentDescription = "Move to inbox")
                    }
                    MailboxKind.Trash -> IconButton(onClick = { onAction(MailAction.Restore) }) {
                        Icon(Icons.Rounded.RestoreFromTrash, contentDescription = "Restore")
                    }
                    MailboxKind.Drafts -> Unit
                    else -> IconButton(onClick = { onAction(MailAction.Archive) }) {
                        Icon(Icons.Rounded.Archive, contentDescription = "Archive")
                    }
                }
                if (mailbox != MailboxKind.Trash) {
                    IconButton(onClick = { onAction(MailAction.Trash) }) {
                        Icon(Icons.Rounded.Delete, contentDescription = "Move to trash")
                    }
                }
                IconButton(onClick = { onAction(if (allRead) MailAction.Unread else MailAction.Read) }) {
                    Icon(
                        if (allRead) Icons.Outlined.MarkEmailUnread else Icons.Rounded.MarkEmailRead,
                        contentDescription = if (allRead) "Mark as unread" else "Mark as read"
                    )
                }
                IconButton(onClick = onMore) { Icon(Icons.Rounded.MoreVert, contentDescription = "More actions") }
            },
            windowInsets = WindowInsets(0, 0, 0, 0),
            colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
        )
        Row(
            modifier = Modifier.fillMaxWidth().clickable(onClick = onToggleAll).padding(horizontal = 20.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(checked = allSelected, onCheckedChange = { onToggleAll() })
            Spacer(Modifier.width(12.dp))
            Text(
                if (allSelected) "Clear all" else "Select all",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun SwipeableMailThreadItem(
    thread: ThreadSummary,
    mailbox: MailboxKind,
    controls: MailboxSwipeControls,
    first: Boolean,
    last: Boolean,
    selected: Boolean,
    selectionActive: Boolean,
    working: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    onSwipeAction: (MailAction) -> Unit,
    onStar: () -> Unit
) {
    val startAction = controls.startToEnd.toThreadSwipeAction(thread)
    val endAction = controls.endToStart.toThreadSwipeAction(thread)
    val swipeEnabled = !selectionActive && !working
    val currentStartAction = rememberUpdatedState(startAction)
    val currentEndAction = rememberUpdatedState(endAction)
    val currentOnSwipeAction = rememberUpdatedState(onSwipeAction)
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            val action = when (value) {
                SwipeToDismissBoxValue.StartToEnd -> currentStartAction.value?.action
                SwipeToDismissBoxValue.EndToStart -> currentEndAction.value?.action
                SwipeToDismissBoxValue.Settled -> null
            }
            if (action != null) currentOnSwipeAction.value(action)
            false
        },
        positionalThreshold = { distance -> distance * 0.5f }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            val swipeAction = when (dismissState.dismissDirection) {
                SwipeToDismissBoxValue.StartToEnd -> startAction
                SwipeToDismissBoxValue.EndToStart -> endAction
                SwipeToDismissBoxValue.Settled -> null
            }
            SwipeActionBackground(
                action = swipeAction,
                direction = dismissState.dismissDirection,
                progress = dismissState.progress,
                first = first,
                last = last
            )
        },
        enableDismissFromStartToEnd = swipeEnabled && startAction != null,
        enableDismissFromEndToStart = swipeEnabled && endAction != null
    ) {
        MailThreadItem(
            thread = thread,
            mailbox = mailbox,
            first = first,
            last = last,
            selected = selected,
            selectionActive = selectionActive,
            working = working,
            onClick = onClick,
            onLongClick = onLongClick,
            onStar = onStar
        )
    }
}

private data class ThreadSwipeAction(
    val control: SwipeControl,
    val action: MailAction,
    val label: String,
    val destructive: Boolean = false
)

private fun SwipeControl.toThreadSwipeAction(thread: ThreadSummary): ThreadSwipeAction? {
    val action = resolve(thread) ?: return null
    val label = when (action) {
        MailAction.Read -> "Mark read"
        MailAction.Unread -> "Mark unread"
        MailAction.Star -> "Star"
        MailAction.Unstar -> "Unstar"
        MailAction.Archive -> "Archive"
        MailAction.Unarchive -> "Move to inbox"
        MailAction.Trash -> "Move to trash"
        MailAction.Restore -> "Restore"
        MailAction.Delete -> "Delete forever"
        else -> title
    }
    return ThreadSwipeAction(
        control = this,
        action = action,
        label = label,
        destructive = action == MailAction.Trash || action == MailAction.Delete
    )
}

@Composable
private fun SwipeActionBackground(
    action: ThreadSwipeAction?,
    direction: SwipeToDismissBoxValue,
    progress: Float,
    first: Boolean,
    last: Boolean
) {
    val revealedProgress = progress.coerceIn(0f, 1f)
    val targetBackgroundColor = when {
        action == null -> MaterialTheme.colorScheme.surfaceContainer
        action.destructive -> MaterialTheme.colorScheme.errorContainer
        else -> MaterialTheme.colorScheme.primaryContainer
    }
    val backgroundColor = lerp(
        MaterialTheme.colorScheme.surfaceContainer,
        targetBackgroundColor,
        revealedProgress
    )
    val contentColor = when {
        action == null -> Color.Transparent
        action.destructive -> MaterialTheme.colorScheme.onErrorContainer
        else -> MaterialTheme.colorScheme.onPrimaryContainer
    }
    val alignment = when (direction) {
        SwipeToDismissBoxValue.EndToStart -> Alignment.CenterEnd
        else -> Alignment.CenterStart
    }
    val animationProgress = (revealedProgress / 0.4f).coerceIn(0f, 1f)

    Surface(
        modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp),
        shape = RoundedCornerShape(
            topStart = if (first) 16.dp else 0.dp,
            topEnd = if (first) 16.dp else 0.dp,
            bottomStart = if (last) 16.dp else 0.dp,
            bottomEnd = if (last) 16.dp else 0.dp
        ),
        color = backgroundColor
    ) {
        if (action != null) {
            Box(
                modifier = Modifier.fillMaxSize().padding(horizontal = 28.dp),
                contentAlignment = alignment
            ) {
                SwipeControlIcon(
                    control = action.control,
                    progress = animationProgress,
                    color = contentColor,
                    modifier = Modifier.size(32.dp),
                    resolvedAction = action.action
                )
            }
        }
    }
}

@Composable
@OptIn(ExperimentalFoundationApi::class)
private fun MailThreadItem(
    thread: ThreadSummary,
    mailbox: MailboxKind,
    first: Boolean,
    last: Boolean,
    selected: Boolean,
    selectionActive: Boolean,
    working: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    onStar: () -> Unit
) {
    val people = thread.senderPeople()
    val peopleText = people.joinToString(", ")
    val fallback = when (mailbox) {
        MailboxKind.Drafts, MailboxKind.Sent -> "No recipient"
        else -> "Unknown sender"
    }
    val correspondent = when (mailbox) {
        MailboxKind.Sent, MailboxKind.Drafts -> if (peopleText.isBlank()) fallback else "To: $peopleText"
        else -> peopleText.ifBlank { fallback }
    }
    val tileName = peopleText.ifBlank { fallback }
    val container = when {
        selected -> MaterialTheme.colorScheme.secondaryContainer
        LocalQuickInboxDarkTheme.current -> MaterialTheme.colorScheme.surfaceContainerLow
        else -> MaterialTheme.colorScheme.surfaceContainerLowest
    }

    Surface(
        modifier = Modifier.padding(horizontal = 8.dp),
        shape = RoundedCornerShape(
            topStart = if (first) 16.dp else 0.dp,
            topEnd = if (first) 16.dp else 0.dp,
            bottomStart = if (last) 16.dp else 0.dp,
            bottomEnd = if (last) 16.dp else 0.dp
        ),
        color = container
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .combinedClickable(
                    enabled = !working,
                    onClick = onClick,
                    onLongClick = onLongClick
                )
                .padding(start = 16.dp, end = 8.dp, top = 12.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (selected) {
                Surface(
                    modifier = Modifier.size(40.dp),
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primary
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            Icons.Rounded.Check,
                            contentDescription = "Selected",
                            tint = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                }
            } else {
                SenderTile(name = tileName, size = 40.dp)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = buildAnnotatedString {
                            append(correspondent)
                            if (thread.messageCount > 1) {
                                withStyle(
                                    SpanStyle(
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontWeight = FontWeight.Normal
                                    )
                                ) { append("  ${thread.messageCount}") }
                            }
                        },
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = if (thread.isRead) FontWeight.Normal else FontWeight.Bold,
                        color = if (thread.isRead) MaterialTheme.colorScheme.onSurfaceVariant
                        else MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = thread.createdAt?.mailboxRelativeLabel().orEmpty(),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (thread.isRead) FontWeight.Normal else FontWeight.Bold,
                        color = if (!thread.isRead) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1
                    )
                    if (!thread.isRead) {
                        Spacer(Modifier.width(6.dp))
                        Box(
                            Modifier
                                .size(8.dp)
                                .background(MaterialTheme.colorScheme.primary, CircleShape)
                                .semantics { stateDescription = "Unread" }
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = thread.subject.ifBlank { "(No subject)" },
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (thread.isRead) FontWeight.Normal else FontWeight.Bold,
                        color = if (thread.isRead) MaterialTheme.colorScheme.onSurfaceVariant
                        else MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (thread.hasAttachments) {
                        Spacer(Modifier.width(6.dp))
                        Icon(
                            Icons.Rounded.AttachFile,
                            contentDescription = "Has attachments",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                if (thread.preview.isNotBlank()) {
                    Text(
                        text = thread.preview,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
            when {
                working -> Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                }
                selectionActive -> Spacer(Modifier.size(48.dp))
                else -> IconButton(onClick = onStar) {
                    Icon(
                        if (thread.isStarred) Icons.Rounded.Star else Icons.Outlined.StarOutline,
                        contentDescription = if (thread.isStarred) "Remove star" else "Add star",
                        tint = if (thread.isStarred) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

private data class ActionItem(
    val action: MailAction,
    val label: String,
    val icon: ImageVector,
    val destructive: Boolean = false
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationActionsSheet(
    targets: List<ThreadSummary>,
    mailbox: MailboxKind,
    onDismiss: () -> Unit,
    onAction: (MailAction) -> Unit
) {
    var confirmDelete by remember { mutableStateOf(false) }
    val allRead = targets.all { it.isRead }
    val allStarred = targets.all { it.isStarred }
    val actions = buildList {
        add(ActionItem(if (allRead) MailAction.Unread else MailAction.Read, if (allRead) "Mark as unread" else "Mark as read", if (allRead) Icons.Outlined.MarkEmailUnread else Icons.Rounded.MarkEmailRead))
        add(ActionItem(if (allStarred) MailAction.Unstar else MailAction.Star, if (allStarred) "Remove star" else "Add star", if (allStarred) Icons.Outlined.StarOutline else Icons.Rounded.Star))
        when {
            mailbox == MailboxKind.Archive -> add(ActionItem(MailAction.Unarchive, "Move to inbox", Icons.Rounded.Unarchive))
            mailbox != MailboxKind.Trash && mailbox != MailboxKind.Drafts -> add(ActionItem(MailAction.Archive, "Archive", Icons.Rounded.Archive))
        }
        if (mailbox == MailboxKind.Trash) {
            add(ActionItem(MailAction.Restore, "Restore", Icons.Rounded.RestoreFromTrash))
            add(ActionItem(MailAction.Delete, "Delete forever", Icons.Rounded.Delete, destructive = true))
        } else {
            add(ActionItem(MailAction.Trash, "Move to trash", Icons.Rounded.Delete))
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(bottom = 24.dp)) {
            Text(
                if (targets.size == 1) "Conversation actions" else "${targets.size} conversations",
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold
            )
            actions.forEach { item ->
                ListItem(
                    headlineContent = {
                        Text(
                            item.label,
                            color = if (item.destructive) MaterialTheme.colorScheme.error
                            else MaterialTheme.colorScheme.onSurface
                        )
                    },
                    leadingContent = {
                        Icon(
                            item.icon,
                            contentDescription = null,
                            tint = if (item.destructive) MaterialTheme.colorScheme.error
                            else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    },
                    modifier = Modifier.clickable {
                        if (item.action == MailAction.Delete) confirmDelete = true else onAction(item.action)
                    }
                )
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            icon = { Icon(Icons.Rounded.Delete, contentDescription = null) },
            title = { Text(if (targets.size == 1) "Delete forever?" else "Delete ${targets.size} conversations?") },
            text = { Text("This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = { onAction(MailAction.Delete) }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun LoadingState() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(message, color = MaterialTheme.colorScheme.error)
            Spacer(Modifier.height(12.dp))
            TextButton(onClick = onRetry) { Text("Try again") }
        }
    }
}

@Composable
private fun EmptyState(mailbox: MailboxKind) {
    Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerHigh) {
                Icon(
                    mailbox.icon,
                    contentDescription = null,
                    modifier = Modifier.padding(18.dp).size(28.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(Modifier.height(16.dp))
            Text(mailbox.emptyTitle, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            Text(mailbox.emptyDescription, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

private fun ThreadSummary.senderPeople(): List<String> {
    val others = participants.filterNot { it.selfParticipant }.ifEmpty { participants }
    return others.map { it.displayLabel }.filter { it.isNotEmpty() }
}

private fun Set<String>.toggling(id: String): Set<String> = if (id in this) this - id else this + id

internal val MailboxKind.icon: ImageVector
    get() = when (this) {
        MailboxKind.Inbox -> Icons.Rounded.Inbox
        MailboxKind.Archive -> Icons.Rounded.Archive
        MailboxKind.Starred -> Icons.Rounded.Star
        MailboxKind.Drafts -> Icons.Rounded.Drafts
        MailboxKind.Sent -> Icons.AutoMirrored.Rounded.Send
        MailboxKind.Trash -> Icons.Rounded.Delete
    }
