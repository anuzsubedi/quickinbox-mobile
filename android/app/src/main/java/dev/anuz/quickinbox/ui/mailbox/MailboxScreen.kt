package dev.anuz.quickinbox.ui.mailbox

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.MarkEmailUnread
import androidx.compose.material.icons.rounded.Archive
import androidx.compose.material.icons.rounded.AttachFile
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Drafts
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.MarkEmailUnread
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Unarchive
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FloatingActionButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
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
import dev.anuz.quickinbox.ui.components.SwipeActionSurface
import dev.anuz.quickinbox.ui.components.SwipeActionSpec
import dev.anuz.quickinbox.ui.components.StickySwipeMotion
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
    onToggleStarred: () -> Unit,
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
    val refreshState = rememberPullToRefreshState()
    val haptics = rememberQuickInboxHaptics()
    val drawerState = androidx.compose.material3.rememberDrawerState(androidx.compose.material3.DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var selectedIds by remember { mutableStateOf(emptySet<String>()) }
    var pendingSelectionDelete by remember { mutableStateOf<List<ThreadSummary>?>(null) }
    var pendingSwipeDelete by remember { mutableStateOf<ThreadSummary?>(null) }
    val swipeMotion = remember(state.mailbox, state.searchText, state.unreadOnly, state.starredOnly) { StickySwipeMotion() }
    val selectedThreads = state.threads.filter { it.id in selectedIds }
    val selectionActive = selectedThreads.isNotEmpty()

    BackHandler(enabled = selectionActive) { selectedIds = emptySet() }
    LaunchedEffect(state.mailbox, state.searchText, state.unreadOnly, state.starredOnly) {
        selectedIds = emptySet()
        pendingSelectionDelete = null
        pendingSwipeDelete = null
    }
    LaunchedEffect(state.threads) {
        selectedIds = selectedIds.intersect(state.threads.mapTo(mutableSetOf()) { it.id })
    }
    val isNativeNavigation = navigationStyle == MailboxNavigationStyle.Native
    LaunchedEffect(navigationStyle) { drawerState.close() }
    BackHandler(enabled = isNativeNavigation && !selectionActive && state.mailbox != MailboxKind.Inbox) {
        onSelectMailbox(MailboxKind.Inbox)
    }
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
            info.totalItemsCount > 0 && last >= info.totalItemsCount - 3
        }.distinctUntilChanged().collect { if (it) onLoadNext() }
    }

    fun perform(action: MailAction, targets: List<ThreadSummary>) {
        if (targets.isEmpty()) return
        onAction(action, targets)
        selectedIds = emptySet()
        pendingSelectionDelete = null
    }

    val mailboxContent: @Composable () -> Unit = {
        Scaffold(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
            snackbarHost = { SnackbarHost(snackbar) },
            floatingActionButton = {
                if (!selectionActive) {
                    ComposeFab(elevation = FabElevation, onClick = { onCompose(null) })
                }
            },
            bottomBar = {
                if (selectionActive) {
                    SelectionDock(
                        selected = selectedThreads,
                        mailbox = state.mailbox,
                        onAction = {
                            if (it == MailAction.Delete) pendingSelectionDelete = selectedThreads
                            else perform(it, selectedThreads)
                        }
                    )
                }
                AnimatedVisibility(
                    visible = isNativeNavigation && !selectionActive,
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
                        onSelectMailbox = onSelectMailbox
                    )
                }
            }
        ) { padding ->
            PullToRefreshBox(
                isRefreshing = state.isRefreshing,
                onRefresh = onRefresh,
                state = refreshState,
                indicator = {
                    ExpressiveRefreshIndicator(
                        state = refreshState,
                        isRefreshing = state.isRefreshing,
                        modifier = Modifier.align(Alignment.TopCenter)
                    )
                },
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
                                selectedCount = selectedThreads.size,
                                allSelected = selectedThreads.size == state.threads.size,
                                onToggleAll = {
                                    haptics.selectionChanged()
                                    selectedIds = if (selectedThreads.size == state.threads.size) emptySet()
                                    else state.threads.mapTo(mutableSetOf()) { it.id }
                                },
                                onClose = { selectedIds = emptySet() }
                            )
                        } else {
                            MailboxHeader(
                                mailbox = state.mailbox,
                                searchText = state.searchText,
                                unreadOnly = state.unreadOnly,
                                starredOnly = state.starredOnly,
                                showUnreadFilter = state.mailbox == MailboxKind.Inbox,
                                onSearchChange = onSearchChange,
                                onToggleUnread = onToggleUnread,
                                onToggleStarred = onToggleStarred,
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
                        state.threads.isEmpty() -> EmptyState(state.mailbox, filtered = state.starredOnly || state.unreadOnly || state.searchText.isNotBlank())
                        else -> LazyColumn(
                            state = listState,
                            contentPadding = PaddingValues(bottom = 88.dp),
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            itemsIndexed(state.threads, key = { _, thread -> thread.id }) { index, thread ->
                                SwipeableMailThreadItem(
                                    modifier = Modifier.animateItem(),
                                    index = index,
                                    motion = swipeMotion,
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
        }
    }

    if (isNativeNavigation) {
        mailboxContent()
    } else {
        ModalNavigationDrawer(
            drawerState = drawerState,
            gesturesEnabled = !selectionActive,
            drawerContent = {
                MailboxDrawer(
                    selected = state.mailbox,
                    onClose = { scope.launch { drawerState.close() } },
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

    pendingSelectionDelete?.let { targets ->
        AlertDialog(
            onDismissRequest = { pendingSelectionDelete = null },
            icon = { Icon(Icons.Rounded.Delete, contentDescription = null) },
            title = { Text(if (targets.size == 1) "Delete forever?" else "Delete ${targets.size} conversations?") },
            text = { Text("This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = { perform(MailAction.Delete, targets) }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingSelectionDelete = null }) { Text("Cancel") }
            }
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

/** Subtle elevation for the Compose action in either navigation style. */
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

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun SwipeableMailThreadItem(
    modifier: Modifier,
    index: Int,
    motion: StickySwipeMotion,
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
    SwipeActionSurface(
        startAction = startAction,
        endAction = endAction,
        enabled = !selectionActive && !working,
        index = index,
        motion = motion,
        modifier = modifier,
        onAction = onSwipeAction
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

private fun SwipeControl.toThreadSwipeAction(thread: ThreadSummary): SwipeActionSpec? {
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
    return SwipeActionSpec(
        control = this,
        action = action,
        label = label
    )
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
        // A light accent wash follows both authored themes and Monet's wallpaper colors.
        else -> lerp(MaterialTheme.colorScheme.surface, MaterialTheme.colorScheme.primary, 0.045f)
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
                .padding(start = 16.dp, end = if (selectionActive) 16.dp else 8.dp, top = 12.dp, bottom = 12.dp),
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
                selectionActive -> Unit
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
private fun EmptyState(mailbox: MailboxKind, filtered: Boolean = false) {
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
            Text(if (filtered) "No matching mail" else mailbox.emptyTitle, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            Text(if (filtered) "Try changing your search or filters." else mailbox.emptyDescription, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
