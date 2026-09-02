package dev.anuz.quickinbox.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.anuz.quickinbox.data.AppContainer
import dev.anuz.quickinbox.domain.ThreadSummary
import dev.anuz.quickinbox.domain.User
import dev.anuz.quickinbox.ui.compose.ComposeMode
import dev.anuz.quickinbox.ui.compose.ComposeScreen
import dev.anuz.quickinbox.ui.compose.ComposeViewModel
import dev.anuz.quickinbox.ui.compose.ComposeViewModelFactory
import dev.anuz.quickinbox.ui.mailbox.MailboxScreen
import dev.anuz.quickinbox.ui.mailbox.MailboxViewModel
import dev.anuz.quickinbox.ui.mailbox.MailboxViewModelFactory
import dev.anuz.quickinbox.ui.settings.SettingsScreen
import dev.anuz.quickinbox.ui.theme.QuickInboxMotion
import dev.anuz.quickinbox.ui.thread.ThreadScreen
import dev.anuz.quickinbox.ui.thread.ThreadViewModel
import dev.anuz.quickinbox.ui.thread.ThreadViewModelFactory

private sealed class AuthDestination {
    data object Mailbox : AuthDestination()
    data class Thread(val summary: ThreadSummary) : AuthDestination()
    data class Compose(
        val mode: ComposeMode,
        val returnTo: ThreadSummary? = null,
        val sessionKey: Int
    ) : AuthDestination()
    data object Settings : AuthDestination()
}

private enum class NavTransition {
    ThreadPush,
    SettingsPush,
    ComposeModal
}

/** Picks transition shape and whether navigation is forward (deeper / opening). */
private fun navTransition(
    initial: AuthDestination,
    target: AuthDestination
): Pair<NavTransition, Boolean> {
    val kind = when {
        target is AuthDestination.Compose || initial is AuthDestination.Compose -> NavTransition.ComposeModal
        target is AuthDestination.Settings || initial is AuthDestination.Settings -> NavTransition.SettingsPush
        else -> NavTransition.ThreadPush
    }
    val forward = when (kind) {
        NavTransition.ComposeModal -> target is AuthDestination.Compose
        NavTransition.SettingsPush -> target is AuthDestination.Settings
        NavTransition.ThreadPush -> when {
            target is AuthDestination.Thread -> initial is AuthDestination.Mailbox
            initial is AuthDestination.Thread -> target is AuthDestination.Mailbox
            else -> false
        }
    }
    return kind to forward
}

private fun authDestinationTransitionSpec(
    initial: AuthDestination,
    target: AuthDestination
): androidx.compose.animation.ContentTransform {
    val (kind, forward) = navTransition(initial, target)
    return when (kind) {
        NavTransition.ThreadPush -> if (forward) {
            (fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)) +
                slideInHorizontally(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)) { fullWidth ->
                    fullWidth
                })
                .togetherWith(
                    fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) +
                        slideOutHorizontally(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) { fullWidth ->
                            -fullWidth / 4
                        }
                )
        } else {
            (fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)) +
                slideInHorizontally(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)) { fullWidth ->
                    -fullWidth / 4
                })
                .togetherWith(
                    fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) +
                        slideOutHorizontally(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) { fullWidth ->
                            fullWidth
                        }
                )
        }
        NavTransition.SettingsPush -> if (forward) {
            (fadeIn(tween(QuickInboxMotion.DurationLong, easing = QuickInboxMotion.Emphasized)) +
                slideInHorizontally(tween(QuickInboxMotion.DurationLong, easing = QuickInboxMotion.Emphasized)) { fullWidth ->
                    fullWidth / 2
                })
                .togetherWith(
                    fadeOut(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Decelerate)) +
                        slideOutHorizontally(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Decelerate)) { fullWidth ->
                            -fullWidth / 6
                        }
                )
        } else {
            (fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)) +
                slideInHorizontally(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)) { fullWidth ->
                    -fullWidth / 6
                })
                .togetherWith(
                    fadeOut(tween(QuickInboxMotion.DurationLong, easing = QuickInboxMotion.Decelerate)) +
                        slideOutHorizontally(tween(QuickInboxMotion.DurationLong, easing = QuickInboxMotion.Decelerate)) { fullWidth ->
                            fullWidth / 2
                        }
                )
        }
        NavTransition.ComposeModal -> if (forward) {
            (fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Emphasized)) +
                slideInVertically(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Emphasized)) { fullHeight ->
                    fullHeight
                })
                .togetherWith(
                    fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) +
                        slideOutVertically(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) { fullHeight ->
                            -fullHeight / 5
                        }
                )
        } else {
            (fadeIn(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Standard)) +
                slideInVertically(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Standard)) { fullHeight ->
                    -fullHeight / 5
                })
                .togetherWith(
                    fadeOut(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Decelerate)) +
                        slideOutVertically(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Decelerate)) { fullHeight ->
                            fullHeight
                        }
                )
        }
    }
}

@Composable
fun AuthenticatedRoot(
    container: AppContainer,
    user: User,
    onDisconnected: (String?) -> Unit
) {
    var destination by remember { mutableStateOf<AuthDestination>(AuthDestination.Mailbox) }
    var mailboxRefresh by remember { mutableStateOf(0) }
    var composeSession by remember { mutableStateOf(0) }
    val mailboxViewModel: MailboxViewModel = viewModel(
        key = user.id,
        factory = MailboxViewModelFactory(
            container.api,
            user.id,
            container.mailboxCache,
            container.threadCache
        )
    )
    val mailboxState by mailboxViewModel.state.collectAsStateWithLifecycle()
    val mailboxNavigationStyle by container.preferences.mailboxNavigationStyle.collectAsStateWithLifecycle()
    val mailboxSwipeControls by container.preferences.mailboxSwipeControls.collectAsStateWithLifecycle()
    val navigationPromptPending by container.preferences.navigationPromptPending.collectAsStateWithLifecycle()

    LaunchedEffect(user.id, mailboxRefresh) {
        mailboxViewModel.bootstrap()
        if (mailboxRefresh > 0) mailboxViewModel.reload(showInitialLoading = false)
    }

    AnimatedContent(
        targetState = destination,
        transitionSpec = { authDestinationTransitionSpec(initialState, targetState) },
        label = "auth-destination"
    ) { current ->
        when (current) {
            AuthDestination.Mailbox -> MailboxScreen(
                state = mailboxState,
                navigationStyle = mailboxNavigationStyle,
                swipeControls = mailboxSwipeControls,
                onSelectMailbox = mailboxViewModel::selectMailbox,
                onSearchChange = mailboxViewModel::onSearchChange,
                onToggleUnread = mailboxViewModel::toggleUnreadOnly,
                onRefresh = mailboxViewModel::refresh,
                onLoadNext = mailboxViewModel::loadNextPage,
                onOpenThread = { destination = AuthDestination.Thread(it) },
                onCompose = {
                    composeSession += 1
                    destination = AuthDestination.Compose(
                        mode = it?.let(ComposeMode::Draft) ?: ComposeMode.NewMessage,
                        sessionKey = composeSession
                    )
                },
                onOpenSettings = { destination = AuthDestination.Settings },
                onAction = mailboxViewModel::perform,
                onDismissError = mailboxViewModel::dismissErrors
            )
            is AuthDestination.Thread -> {
                BackHandler { destination = AuthDestination.Mailbox }
                val context = LocalContext.current
                val threadViewModel: ThreadViewModel = viewModel(
                    key = current.summary.id,
                    factory = ThreadViewModelFactory(
                        container.api,
                        current.summary.threadId,
                        current.summary,
                        context.cacheDir,
                        user.id,
                        container.threadCache
                    )
                )
                val threadState by threadViewModel.state.collectAsStateWithLifecycle()
                LaunchedEffect(current.summary.id) { threadViewModel.load() }
                ThreadScreen(
                    state = threadState,
                    summary = current.summary,
                    preferences = container.preferences,
                    onBack = { destination = AuthDestination.Mailbox },
                    onCompose = {
                        composeSession += 1
                        destination = AuthDestination.Compose(
                            mode = it,
                            returnTo = current.summary,
                            sessionKey = composeSession
                        )
                    },
                    onAction = { action ->
                        threadViewModel.perform(action, onMailboxMutation = { mailboxRefresh += 1 }, onExit = {
                            destination = AuthDestination.Mailbox
                        })
                    },
                    onDownload = threadViewModel::download,
                    onOpenedAttachmentConsumed = threadViewModel::consumeOpenedAttachment
                )
            }
            is AuthDestination.Compose -> {
                val returnDestination = current.returnTo?.let(AuthDestination::Thread) ?: AuthDestination.Mailbox
                BackHandler { destination = returnDestination }
                val composeViewModel: ComposeViewModel = viewModel(
                    key = "${current.mode}:${current.sessionKey}",
                    factory = ComposeViewModelFactory(container.api, current.mode, container.preferences)
                )
                val composeState by composeViewModel.state.collectAsStateWithLifecycle()
                LaunchedEffect(current.mode) { composeViewModel.load() }
                val context = LocalContext.current
                ComposeScreen(
                    mode = current.mode,
                    state = composeState,
                    onBack = { destination = returnDestination },
                    onTo = composeViewModel::onTo,
                    onCc = composeViewModel::onCc,
                    onBcc = composeViewModel::onBcc,
                    onSubject = composeViewModel::onSubject,
                    onBody = composeViewModel::onBody,
                    onFrom = composeViewModel::onFrom,
                    onIncludeOriginalAttachments = composeViewModel::onIncludeOriginalAttachments,
                    onSend = {
                        composeViewModel.send {
                            val affectedThreadId = current.returnTo?.threadId
                                ?: (current.mode as? ComposeMode.Forward.Thread)?.threadId
                            val origin = container.api.credential?.origin
                            if (affectedThreadId != null && origin != null) {
                                runCatching {
                                    container.threadCache.remove(origin, user.id, affectedThreadId)
                                }
                            }
                            mailboxRefresh += 1
                            destination = AuthDestination.Mailbox
                        }
                    },
                    onImport = { uris -> composeViewModel.importUris(context, uris) },
                    onRemoveAttachment = composeViewModel::removeAttachment
                )
            }
            AuthDestination.Settings -> {
                BackHandler { destination = AuthDestination.Mailbox }
                SettingsScreen(
                    container = container,
                    user = user,
                    onBack = { destination = AuthDestination.Mailbox },
                    onDisconnected = onDisconnected
                )
            }
        }
    }

    if (navigationPromptPending) {
        NavigationStylePrompt(
            initialStyle = mailboxNavigationStyle,
            onConfirm = container.preferences::completeNavigationPrompt
        )
    }
}

@Composable
fun LaunchScreen() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}
