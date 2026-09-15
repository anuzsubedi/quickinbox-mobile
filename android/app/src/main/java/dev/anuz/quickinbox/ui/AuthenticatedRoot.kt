package dev.anuz.quickinbox.ui

import android.net.Uri
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializer
import com.google.gson.JsonSerializer
import dev.anuz.quickinbox.data.ApiDateAdapter
import java.util.Date

import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.dp
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarResult
import dev.anuz.quickinbox.ui.mailbox.supportsUndo
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
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
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
import dev.anuz.quickinbox.ui.thread.ThreadScreen
import dev.anuz.quickinbox.ui.thread.ThreadViewModel
import dev.anuz.quickinbox.ui.thread.ThreadViewModelFactory

internal sealed class AuthDestination {
    data object Mailbox : AuthDestination()
    data class Thread(val summary: ThreadSummary) : AuthDestination()
    data class Compose(
        val mode: ComposeMode,
        val returnTo: ThreadSummary? = null,
        val sessionKey: Int
    ) : AuthDestination()
    data object Settings : AuthDestination()
}

@Composable
fun AuthenticatedRoot(
    container: AppContainer,
    user: User,
    onDisconnected: (String?) -> Unit
) {
    val navController = rememberNavController()
    val routeGson = remember { navigationGson() }
    fun navigate(destination: AuthDestination) {
        when (destination) {
            AuthDestination.Mailbox -> navController.popBackStack("mailbox", false)
            AuthDestination.Settings -> navController.navigate("settings") { launchSingleTop = true }
            is AuthDestination.Thread -> navController.navigate("thread/${Uri.encode(routeGson.toJson(destination))}") { launchSingleTop = true }
            is AuthDestination.Compose -> navController.navigate("compose/${Uri.encode(routeGson.toJson(destination))}") { launchSingleTop = true }
        }
    }
    val mailboxListState = rememberLazyListState()
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
    val undoOffer by mailboxViewModel.undoOffer.collectAsStateWithLifecycle()
    val undoSnackbar = remember { SnackbarHostState() }
    LaunchedEffect(undoOffer?.id) {
        val offer = undoOffer ?: return@LaunchedEffect
        try {
            val result = undoSnackbar.showSnackbar(offer.message, "Undo", withDismissAction = true, duration = SnackbarDuration.Long)
            mailboxViewModel.resolveUndo(offer.id, result == SnackbarResult.ActionPerformed)
        } finally {
            mailboxViewModel.resolveUndo(offer.id, false)
        }
    }
    val mailboxNavigationStyle by container.preferences.mailboxNavigationStyle.collectAsStateWithLifecycle()
    val mailboxSwipeControls by container.preferences.mailboxSwipeControls.collectAsStateWithLifecycle()
    val navigationPromptPending by container.preferences.navigationPromptPending.collectAsStateWithLifecycle()

    LaunchedEffect(user.id, mailboxRefresh) {
        mailboxViewModel.bootstrap()
        if (mailboxRefresh > 0) mailboxViewModel.reload(showInitialLoading = false)
    }

    Box(Modifier.fillMaxSize()) {
        QuickInboxNavHost(navController, startDestination = "mailbox") {
            composable("mailbox") {
                MailboxScreen(
                    state = mailboxState,
                    listState = mailboxListState,
                    navigationStyle = mailboxNavigationStyle,
                    swipeControls = mailboxSwipeControls,
                    onSelectMailbox = mailboxViewModel::selectMailbox,
                    onSearchChange = mailboxViewModel::onSearchChange,
                    onToggleUnread = mailboxViewModel::toggleUnreadOnly,
                    onToggleStarred = mailboxViewModel::toggleStarredOnly,
                    onRefresh = mailboxViewModel::refresh,
                    onLoadNext = mailboxViewModel::loadNextPage,
                    onOpenThread = { navigate(AuthDestination.Thread(it)) },
                    onCompose = {
                        composeSession += 1
                        navigate(AuthDestination.Compose(
                            mode = it?.let(ComposeMode::Draft) ?: ComposeMode.NewMessage,
                            sessionKey = composeSession
                        ))
                    },
                    onOpenSettings = { navigate(AuthDestination.Settings) },
                    onAction = mailboxViewModel::perform,
                    onDismissError = mailboxViewModel::dismissErrors
                )
            }
            composable("thread/{payload}") { entry ->
                    val current = remember(entry) {
                        routeGson.fromJson(entry.arguments!!.getString("payload"), AuthDestination.Thread::class.java)
                    }
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
                    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
                        threadViewModel.load { detail -> mailboxViewModel.onThreadLoaded(current.summary, detail) }
                    }
                    ThreadScreen(
                        state = threadState,
                        summary = current.summary,
                        preferences = container.preferences,
                        onRetry = {
                            threadViewModel.load { detail -> mailboxViewModel.onThreadLoaded(current.summary, detail) }
                        },
                        onBack = { navigate(AuthDestination.Mailbox) },
                        onCompose = {
                            composeSession += 1
                            navigate(AuthDestination.Compose(
                                mode = it,
                                returnTo = current.summary,
                                sessionKey = composeSession
                            ))
                        },
                        onAction = { action ->
                            if (action.supportsUndo()) {
                                val updated = current.summary.copy(isRead = threadState.isRead, isStarred = threadState.isStarred, isArchived = threadState.isArchived)
                                mailboxViewModel.perform(action, listOf(updated))
                                navigate(AuthDestination.Mailbox)
                            } else threadViewModel.perform(action, onMailboxMutation = {
                                mailboxViewModel.onThreadMutation(action, current.summary)
                                mailboxViewModel.refresh()
                            }, onExit = {
                                navigate(AuthDestination.Mailbox)
                            })
                        },
                        onDownload = threadViewModel::download,
                        onOpenedAttachmentConsumed = threadViewModel::consumeOpenedAttachment
                    )
                }
            composable("compose/{payload}") { entry ->
                    val current = remember(entry) {
                        routeGson.fromJson(entry.arguments!!.getString("payload"), AuthDestination.Compose::class.java)
                    }
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
                        onBack = { navController.popBackStack() },
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
                                navigate(AuthDestination.Mailbox)
                            }
                        },
                        onImport = { uris -> composeViewModel.importUris(context, uris) },
                        onRemoveAttachment = composeViewModel::removeAttachment
                    )
                }
            composable("settings") {
                    SettingsScreen(
                        container = container,
                        user = user,
                        onBack = { navigate(AuthDestination.Mailbox) },
                        onDisconnected = onDisconnected
                    )
                }
        }

        SnackbarHost(undoSnackbar, Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 88.dp))
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

internal fun navigationGson() = GsonBuilder()
    .registerTypeAdapter(Date::class.java, ApiDateAdapter())
    .registerTypeAdapter(ComposeMode::class.java, JsonSerializer<ComposeMode> { mode, _, context ->
        val kind = when (mode) {
            ComposeMode.NewMessage -> "new"
            is ComposeMode.Draft -> "draft"
            is ComposeMode.Reply -> "reply"
            is ComposeMode.Forward.Message -> "forward-message"
            is ComposeMode.Forward.Thread -> "forward-thread"
        }
        com.google.gson.JsonObject().apply {
            addProperty("kind", kind)
            add("value", context.serialize(mode, mode.javaClass))
        }
    })
    .registerTypeAdapter(ComposeMode::class.java, JsonDeserializer<ComposeMode> { json, _, context ->
        val envelope = json.asJsonObject
        when (envelope.get("kind").asString) {
            "new" -> ComposeMode.NewMessage
            "draft" -> context.deserialize<ComposeMode>(envelope.get("value"), ComposeMode.Draft::class.java)
            "reply" -> context.deserialize<ComposeMode>(envelope.get("value"), ComposeMode.Reply::class.java)
            "forward-message" -> context.deserialize<ComposeMode>(envelope.get("value"), ComposeMode.Forward.Message::class.java)
            "forward-thread" -> context.deserialize<ComposeMode>(envelope.get("value"), ComposeMode.Forward.Thread::class.java)
            else -> error("Unknown compose route")
        }
    })
    .create()
