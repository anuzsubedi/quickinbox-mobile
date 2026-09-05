package dev.anuz.quickinbox.ui.settings

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.HelpOutline
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import dev.anuz.quickinbox.data.AppContainer
import dev.anuz.quickinbox.data.ConfigurableSwipeMailboxes
import dev.anuz.quickinbox.data.MailboxSwipeControls
import dev.anuz.quickinbox.data.MailboxNavigationStyle
import dev.anuz.quickinbox.data.SwipeControl
import dev.anuz.quickinbox.data.SwipeDirection
import dev.anuz.quickinbox.data.availableSwipeControls
import dev.anuz.quickinbox.data.defaultSwipeControls
import dev.anuz.quickinbox.domain.DeviceSession
import dev.anuz.quickinbox.domain.MailAddress
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.User
import dev.anuz.quickinbox.ui.privacy.PrivacyScreen
import dev.anuz.quickinbox.ui.theme.AppThemeOption
import dev.anuz.quickinbox.ui.theme.QuickInboxMotion
import dev.anuz.quickinbox.ui.theme.rememberAppColorScheme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class SettingsPage(val title: String) {
    Overview("Settings"), Account("Account"), Appearance("Appearance"),
    Composing("Composing"), SwipeActions("Swipe actions"), Privacy("Privacy & security"), Devices("Connected devices"),
    Connection("Server & session"), Support("Support"), PrivacyPolicy("Privacy policy")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    container: AppContainer,
    user: User,
    onBack: () -> Unit,
    onDisconnected: (String?) -> Unit
) {
    val scope = rememberCoroutineScope()
    val activity = LocalContext.current as? FragmentActivity
    var page by rememberSaveable { mutableStateOf(SettingsPage.Overview) }
    var addresses by remember { mutableStateOf<List<MailAddress>>(emptyList()) }
    var devices by remember { mutableStateOf<List<DeviceSession>>(emptyList()) }
    var signature by remember { mutableStateOf("") }
    var savedSignature by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(true) }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var fromOpen by remember { mutableStateOf(false) }
    var confirmDisconnect by remember { mutableStateOf(false) }
    var confirmLocal by remember { mutableStateOf(false) }
    var deviceToRevoke by remember { mutableStateOf<DeviceSession?>(null) }
    var remoteImages by remember { mutableStateOf(container.preferences.showRemoteImagesByDefault) }
    val snackbarHostState = remember { SnackbarHostState() }
    val themeId by container.preferences.themeId.collectAsState()
    val mailboxNavigationStyle by container.preferences.mailboxNavigationStyle.collectAsState()
    val mailboxSwipeControls by container.preferences.mailboxSwipeControls.collectAsState()
    val appLockState by container.appLock.state.collectAsState()
    val selectedId = container.preferences.selectedSendingAddressId

    fun navigateBack() {
        if (page == SettingsPage.Overview) onBack() else page = SettingsPage.Overview
    }
    BackHandler(onBack = ::navigateBack)

    LaunchedEffect(error) {
        error?.let {
            snackbarHostState.showSnackbar(it)
            error = null
        }
    }

    LaunchedEffect(user.id) {
        loading = true
        try {
            addresses = withContext(Dispatchers.IO) { container.api.addresses() }
            signature = withContext(Dispatchers.IO) {
                callOrDefault("") { container.api.signature() }
            }
            savedSignature = signature
            devices = withContext(Dispatchers.IO) {
                callOrDefault(emptyList<DeviceSession>()) { container.api.devices() }
            }
            if (container.preferences.selectedSendingAddressId == null) {
                container.preferences.selectedSendingAddressId =
                    addresses.firstOrNull { it.isDefault }?.id ?: addresses.firstOrNull()?.id
            }
        } catch (exception: CancellationException) {
            throw exception
        } catch (exception: Exception) {
            error = exception.message
        } finally {
            loading = false
        }
    }

    if (page == SettingsPage.PrivacyPolicy) {
        PrivacyScreen(onBack = { page = SettingsPage.Overview })
        return
    }

    fun saveSignature() {
        scope.launch {
            saving = true
            error = null
            try {
                signature = withContext(Dispatchers.IO) { container.api.updateSignature(signature) }
                savedSignature = signature
                snackbarHostState.showSnackbar("Signature saved")
            } catch (exception: CancellationException) {
                throw exception
            } catch (exception: Exception) {
                error = exception.message
            } finally {
                saving = false
            }
        }
    }

    SettingsScaffold(
        title = page.title,
        root = page == SettingsPage.Overview,
        onBack = ::navigateBack,
        snackbarHostState = snackbarHostState,
        actions = {
            if (page == SettingsPage.Composing) {
                FilledTonalButton(
                    onClick = ::saveSignature,
                    enabled = !loading && !saving && signature != savedSignature,
                    modifier = Modifier.padding(end = 12.dp),
                    shape = MaterialTheme.shapes.large
                ) {
                    if (saving) {
                        CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                    } else {
                        Text("Save")
                    }
                }
            }
        }
    ) { padding ->
        AnimatedContent(
            targetState = page,
            transitionSpec = {
                val enteringSubpage = targetState != SettingsPage.Overview
                val direction = if (enteringSubpage) {
                    AnimatedContentTransitionScope.SlideDirection.Left
                } else {
                    AnimatedContentTransitionScope.SlideDirection.Right
                }
                (slideIntoContainer(
                    direction,
                    animationSpec = tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)
                ) + fadeIn(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Standard))) togetherWith
                    (slideOutOfContainer(
                        direction,
                        animationSpec = tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)
                    ) + fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Standard)))
            },
            label = "settings page"
        ) { currentPage -> when (currentPage) {
            SettingsPage.Overview -> SettingsOverview(
                padding, user, loading, devices.size, appLockState.isEnabled,
                themeTitle = AppThemeOption.fromId(themeId).title,
                onNavigate = { page = it }
            )
            SettingsPage.Account -> AccountPage(padding, user, container.api.credential?.origin)
            SettingsPage.Appearance -> AppearancePage(
                padding = padding,
                selectedId = themeId,
                navigationStyle = mailboxNavigationStyle,
                onThemeSelected = { container.preferences.selectedThemeId = it },
                onNavigationStyleChanged = { container.preferences.selectedMailboxNavigationStyle = it }
            )
            SettingsPage.Composing -> ComposingPage(
                padding, addresses, selectedId, signature, saving, fromOpen,
                onFromOpenChange = { fromOpen = it },
                onAddress = {
                    container.preferences.selectedSendingAddressId = it
                    fromOpen = false
                },
                onSignature = { if (it.length <= 1000) signature = it }
            )
            SettingsPage.SwipeActions -> SwipeActionsPage(
                padding = padding,
                controls = mailboxSwipeControls,
                onControlChanged = container.preferences::setSwipeControl,
                onRestoreDefaults = container.preferences::resetSwipeControls
            )
            SettingsPage.Privacy -> PrivacyPage(
                padding = padding,
                remoteImages = remoteImages,
                appLockState = appLockState,
                onAppLock = { enabled ->
                    activity?.let { container.appLock.requestSetEnabled(it, enabled) }
                },
                onRemoteImages = {
                    remoteImages = it
                    container.preferences.showRemoteImagesByDefault = it
                }
            )
            SettingsPage.Devices -> DevicesPage(padding, devices, loading, onRevoke = { deviceToRevoke = it })
            SettingsPage.Connection -> ConnectionPage(
                padding, container.api.credential?.origin,
                onDisconnect = { confirmDisconnect = true },
                onRemoveLocal = { confirmLocal = true }
            )
            SettingsPage.Support -> SupportPage(padding)
            SettingsPage.PrivacyPolicy -> Unit
        } }
    }

    deviceToRevoke?.let { device ->
        AlertDialog(
            onDismissRequest = { deviceToRevoke = null },
            icon = { Icon(Icons.Rounded.Devices, contentDescription = null) },
            title = { Text("Revoke this device?") },
            text = { Text("${device.deviceName ?: "This device"} will lose access the next time it contacts your server.") },
            confirmButton = {
                TextButton(onClick = {
                    deviceToRevoke = null
                    scope.launch {
                        try {
                            withContext(Dispatchers.IO) { container.api.revokeDevice(device.id) }
                            devices = devices.filterNot { it.id == device.id }
                            snackbarHostState.showSnackbar("Device revoked")
                        } catch (exception: CancellationException) {
                            throw exception
                        } catch (exception: Exception) {
                            error = exception.message
                        }
                    }
                }) { Text("Revoke", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deviceToRevoke = null }) { Text("Cancel") } }
        )
    }

    if (confirmDisconnect) {
        AlertDialog(
            onDismissRequest = { confirmDisconnect = false },
            icon = { Icon(Icons.AutoMirrored.Rounded.Logout, contentDescription = null) },
            title = { Text("Disconnect this device?") },
            text = { Text("This revokes the session on your server and removes the saved login from this phone.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDisconnect = false
                    scope.launch { onDisconnected(disconnect(container, true, devices)) }
                }) { Text("Disconnect", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDisconnect = false }) { Text("Cancel") } }
        )
    }
    if (confirmLocal) {
        AlertDialog(
            onDismissRequest = { confirmLocal = false },
            icon = { Icon(Icons.Rounded.DeleteOutline, contentDescription = null) },
            title = { Text("Remove local data?") },
            text = { Text("This phone forgets the saved session. The server login stays active until you revoke it.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmLocal = false
                    scope.launch {
                        disconnect(container, false, devices)
                        onDisconnected(null)
                    }
                }) { Text("Remove", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmLocal = false }) { Text("Cancel") } }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsScaffold(
    title: String,
    root: Boolean,
    onBack: () -> Unit,
    snackbarHostState: SnackbarHostState,
    actions: @Composable RowScope.() -> Unit,
    content: @Composable (PaddingValues) -> Unit
) {
    Scaffold(
        containerColor = MaterialTheme.colorScheme.surface,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        title,
                        style = if (root) MaterialTheme.typography.headlineMedium else MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.semantics { heading() }
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack, modifier = Modifier.padding(start = 8.dp)
                        .background(MaterialTheme.colorScheme.surfaceContainerLow, MaterialTheme.shapes.large)) {
                        Icon(
                            if (root) Icons.Rounded.Close else Icons.AutoMirrored.Rounded.ArrowBack,
                            contentDescription = if (root) "Close" else "Back"
                        )
                    }
                },
                actions = actions,
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        content = content
    )
}

@Composable
private fun SettingsOverview(
    padding: PaddingValues,
    user: User,
    loading: Boolean,
    deviceCount: Int,
    appLockEnabled: Boolean,
    themeTitle: String,
    onNavigate: (SettingsPage) -> Unit
) {
    PageBody(padding) {
        AccountCard(user) { onNavigate(SettingsPage.Account) }
        SettingsGroup("Personalization") {
            DestinationRow("Appearance", "Theme and Material colors", Icons.Rounded.Palette, themeTitle) {
                onNavigate(SettingsPage.Appearance)
            }
        }
        SettingsGroup("Mail") {
            DestinationRow("Swipe actions", "Customize Inbox, Archive, and Trash", Icons.Rounded.Swipe) {
                onNavigate(SettingsPage.SwipeActions)
            }
            DestinationRow("Composing", "Sender address and signature", Icons.Rounded.Edit) {
                onNavigate(SettingsPage.Composing)
            }
            DestinationRow(
                "Privacy & security", "App lock and external content", Icons.Rounded.Lock,
                if (appLockEnabled) "On" else "Off"
            ) { onNavigate(SettingsPage.Privacy) }
        }
        SettingsGroup("Account access") {
            DestinationRow(
                "Connected devices", "Manage active sessions", Icons.Rounded.Devices,
                if (loading) null else deviceCount.toString()
            ) {
                onNavigate(SettingsPage.Devices)
            }
            DestinationRow("Server & session", "Connection and local data", Icons.Rounded.Storage) {
                onNavigate(SettingsPage.Connection)
            }
        }
        SettingsGroup("About") {
            DestinationRow("Support", "Get help or report a problem", Icons.AutoMirrored.Rounded.HelpOutline) {
                onNavigate(SettingsPage.Support)
            }
            DestinationRow("Privacy policy", "How QuickInbox handles data", Icons.Rounded.PrivacyTip) {
                onNavigate(SettingsPage.PrivacyPolicy)
            }
        }

    }
}

private data class SwipeEditorTarget(
    val mailbox: MailboxKind,
    val direction: SwipeDirection
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeActionsPage(
    padding: PaddingValues,
    controls: Map<MailboxKind, MailboxSwipeControls>,
    onControlChanged: (MailboxKind, SwipeDirection, SwipeControl) -> Unit,
    onRestoreDefaults: () -> Unit
) {
    var editorTarget by remember { mutableStateOf<SwipeEditorTarget?>(null) }

    PageBody(padding) {
        InfoBanner(Icons.Rounded.Swipe, "Your swipe shortcuts", "Choose what each direction does in every mailbox.")
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            ConfigurableSwipeMailboxes.forEach { mailbox ->
                val mailboxControls = controls[mailbox] ?: defaultSwipeControls(mailbox)
                SwipeMailboxCard(
                    mailbox = mailbox,
                    controls = mailboxControls,
                    onEdit = { direction -> editorTarget = SwipeEditorTarget(mailbox, direction) }
                )
            }
        }
        Surface(
            shape = MaterialTheme.shapes.large,
            color = MaterialTheme.colorScheme.surfaceContainerHigh
        ) {
            Row(
                Modifier.fillMaxWidth().padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    Icons.Rounded.Security,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    "Permanent delete always asks for confirmation.",
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        TextButton(onClick = onRestoreDefaults, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Icon(Icons.Rounded.Restore, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("Restore defaults")
        }
    }

    editorTarget?.let { target ->
        val selected = (controls[target.mailbox] ?: defaultSwipeControls(target.mailbox)).control(target.direction)
        ModalBottomSheet(
            onDismissRequest = { editorTarget = null },
            shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            dragHandle = {
                Box(
                    Modifier.padding(top = 12.dp, bottom = 8.dp)
                        .size(width = 36.dp, height = 4.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.35f))
                )
            }
        ) {
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState())
                    .padding(start = 20.dp, end = 20.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Text(
                    "${target.mailbox.title} · ${if (target.direction == SwipeDirection.StartToEnd) "Swipe right" else "Swipe left"}",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.semantics { heading() }
                )
                Column {
                    availableSwipeControls(target.mailbox).forEach { control ->
                        SwipeChoiceCard(
                            control = control,
                            selected = control == selected,
                            onClick = {
                                onControlChanged(target.mailbox, target.direction, control)
                                editorTarget = null
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SwipeMailboxCard(
    mailbox: MailboxKind,
    controls: MailboxSwipeControls,
    onEdit: (SwipeDirection) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = settingsPanelColor(),
        tonalElevation = 0.dp
    ) {
        Column(
            Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Surface(
                    Modifier.size(34.dp),
                    RoundedCornerShape(11.dp),
                    MaterialTheme.colorScheme.secondaryContainer
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            when (mailbox) {
                                MailboxKind.Inbox -> Icons.Rounded.Inbox
                                MailboxKind.Archive -> Icons.Rounded.Archive
                                MailboxKind.Trash -> Icons.Rounded.DeleteOutline
                                else -> Icons.Rounded.Folder
                            },
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                            tint = MaterialTheme.colorScheme.onSecondaryContainer
                        )
                    }
                }
                Text(
                    mailbox.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                SwipeDirectionTile(
                    label = "Swipe right",
                    directionIcon = Icons.AutoMirrored.Rounded.ArrowForward,
                    control = controls.startToEnd,
                    onClick = { onEdit(SwipeDirection.StartToEnd) },
                    modifier = Modifier.weight(1f)
                )
                SwipeDirectionTile(
                    label = "Swipe left",
                    directionIcon = Icons.AutoMirrored.Rounded.ArrowBack,
                    control = controls.endToStart,
                    onClick = { onEdit(SwipeDirection.EndToStart) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun SwipeDirectionTile(
    label: String,
    directionIcon: ImageVector,
    control: SwipeControl,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val destructive = control == SwipeControl.Trash || control == SwipeControl.Delete
    val accent = if (destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
    val shape = MaterialTheme.shapes.large
    Surface(
        modifier = modifier.clip(shape).clickable(onClick = onClick),
        shape = shape,
        color = if (destructive) {
            MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.52f)
        } else {
            MaterialTheme.colorScheme.surfaceContainerHigh
        },
        border = BorderStroke(1.dp, accent.copy(alpha = 0.16f))
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 13.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(directionIcon, contentDescription = null, modifier = Modifier.size(16.dp), tint = accent)
                Spacer(Modifier.width(5.dp))
                Text(
                    label,
                    style = MaterialTheme.typography.labelSmall,
                    color = accent,
                    fontWeight = FontWeight.Bold
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    control.title,
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun SwipeChoiceCard(
    control: SwipeControl,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val destructive = control == SwipeControl.Trash || control == SwipeControl.Delete
    val selectionColor = if (destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
    val shape = RoundedCornerShape(18.dp)
    Surface(
        modifier = modifier.clip(shape).selectable(selected = selected, role = Role.RadioButton, onClick = onClick),
        shape = shape,
        color = if (selected) {
            if (destructive) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.primaryContainer
        } else {
            Color.Transparent
        }
    ) {
        Row(
            Modifier.fillMaxWidth().defaultMinSize(minHeight = 68.dp).padding(horizontal = 16.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    control.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    control.settingsDescription,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (selected && destructive) {
                        MaterialTheme.colorScheme.onErrorContainer.copy(alpha = 0.72f)
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis
                )
            }
            RadioButton(
                selected = selected,
                onClick = null,
                colors = RadioButtonDefaults.colors(selectedColor = selectionColor)
            )
        }
    }
}

private val SwipeControl.settingsDescription: String
    get() = when (this) {
        SwipeControl.None -> "No action for this direction"
        SwipeControl.ToggleRead -> "Switch between read and unread"
        SwipeControl.ToggleStar -> "Add or remove the star"
        SwipeControl.Archive -> "Remove from the inbox"
        SwipeControl.MoveToInbox -> "Return to the inbox"
        SwipeControl.Trash -> "Move to the trash folder"
        SwipeControl.Restore -> "Return to its previous mailbox"
        SwipeControl.Delete -> "Permanently remove after confirmation"
    }

@Composable
private fun AccountCard(user: User, onClick: (() -> Unit)?) {
    Surface(
        modifier = Modifier.then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        shape = MaterialTheme.shapes.extraLarge,
        color = settingsPanelColor(),
        tonalElevation = 0.dp
    ) {
        Row(
            Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Surface(Modifier.size(52.dp), RoundedCornerShape(18.dp), MaterialTheme.colorScheme.primaryContainer) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        user.name.ifBlank { user.email }.firstOrNull()?.uppercase() ?: "?",
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
            Column(Modifier.weight(1f)) {
                Text(
                    "Your account",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    user.name.ifBlank { user.email },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(user.email, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            if (onClick != null) {
                Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun SettingsGroup(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionLabel(title)
        Column(
            modifier = Modifier.clip(MaterialTheme.shapes.extraLarge),
            verticalArrangement = Arrangement.spacedBy(2.dp),
            content = content
        )
    }
}

@Composable
private fun DestinationRow(
    title: String,
    supporting: String,
    icon: ImageVector,
    detail: String? = null,
    onClick: () -> Unit
) {
    Row(
        Modifier.fillMaxWidth().background(settingsPanelColor()).clickable(role = Role.Button, onClick = onClick)
            .heightIn(min = 80.dp).padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        TonalIcon(icon)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(supporting, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            detail?.let {
                Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
            }
        }
        Icon(Icons.Rounded.ChevronRight, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun PageBody(padding: PaddingValues, content: @Composable ColumnScope.() -> Unit) {
    Box(Modifier.fillMaxSize().padding(padding)) {
        Column(
            Modifier.widthIn(max = 720.dp).fillMaxWidth().align(Alignment.TopCenter)
                .verticalScroll(rememberScrollState())
                .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
            content = content
        )
    }
}

@Composable
private fun AccountPage(padding: PaddingValues, user: User, origin: String?) {
    val context = LocalContext.current
    PageBody(padding) {
        InfoBanner(
            icon = Icons.Rounded.Person,
            title = "Your identity",
            text = "This is the account currently connected to QuickInbox on this device."
        )
        AccountCard(user, onClick = null)
        SettingsGroup("Account details") {
            InfoRow(Icons.Rounded.Email, "Email address", user.email)
            if (origin != null) {
                InfoRow(Icons.Rounded.Storage, "QuickInbox server", Uri.parse(origin).host ?: origin)
            }
        }
        if (origin != null) {
            FilledTonalButton(
                onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("$origin/settings"))) },
                shape = MaterialTheme.shapes.large,
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)
            ) {
                Icon(Icons.AutoMirrored.Rounded.OpenInNew, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Manage account on the web")
            }
        }
    }
}

@Composable
private fun AppearancePage(
    padding: PaddingValues,
    selectedId: String,
    navigationStyle: MailboxNavigationStyle,
    onThemeSelected: (String) -> Unit,
    onNavigationStyleChanged: (MailboxNavigationStyle) -> Unit
) {
    val systemDark = isSystemInDarkTheme()
    val themeOptions = remember {
        AppThemeOption.entries.toList()
    }
    PageBody(padding) {
        InfoBanner(Icons.Rounded.Palette, "Make it yours", "Choose a theme and how you switch between mailboxes.")
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionLabel("Theme")
            val fontScale = LocalDensity.current.fontScale
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val columns = if (maxWidth < 340.dp || fontScale >= 1.3f) 1 else 2
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    themeOptions.chunked(columns).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            row.forEach { option ->
                                ThemeTile(
                                    option = option,
                                    selected = option.id == selectedId,
                                    previewDark = option.forcedDark ?: systemDark,
                                    onClick = { onThemeSelected(option.id) },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            if (row.size < columns) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
        Text(
            AppThemeOption.fromId(selectedId).detail,
            modifier = Modifier.padding(horizontal = 4.dp),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        SettingsGroup("Navigation") {
            SwitchRow(
                title = "Show navigation dock",
                supporting = if (navigationStyle == MailboxNavigationStyle.Native) {
                    "Switch mailboxes from the bottom of the screen"
                } else {
                    "Open mailboxes from the side drawer"
                },
                checked = navigationStyle == MailboxNavigationStyle.Native,
                onCheckedChange = { enabled ->
                    onNavigationStyleChanged(
                        if (enabled) MailboxNavigationStyle.Native else MailboxNavigationStyle.Legacy
                    )
                }
            )
        }
    }
}

@Composable
private fun ThemeTile(
    option: AppThemeOption,
    selected: Boolean,
    previewDark: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val preview = rememberAppColorScheme(option, previewDark)
    Surface(
        modifier = modifier.clip(MaterialTheme.shapes.large)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick),
        shape = MaterialTheme.shapes.large,
        color = settingsPanelColor(),
        border = BorderStroke(
            if (selected) 2.dp else 1.dp,
            if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
        )
    ) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                Modifier.fillMaxWidth().height(64.dp).clip(RoundedCornerShape(12.dp))
                    .background(preview.background)
            ) {
                Row(
                    Modifier.fillMaxSize().padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Swatch(preview.primary, 20.dp)
                    Swatch(preview.secondary, 16.dp)
                    Swatch(preview.surfaceContainerHighest, 12.dp)
                }
                if (selected) {
                    Icon(
                        Icons.Rounded.CheckCircle,
                        contentDescription = "Selected",
                        modifier = Modifier.align(Alignment.TopEnd).padding(6.dp).size(16.dp),
                        tint = preview.primary
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    option.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                if (option == AppThemeOption.FoldedSignal) {
                    SignatureBadge()
                } else {
                    Text(
                        when (option.forcedDark) { true -> "Dark"; false -> "Light"; null -> "Adaptive" },
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun Swatch(color: Color, size: Dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(color)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), CircleShape)
    )
}

@Composable
private fun SignatureBadge() {
    Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.primaryContainer) {
        Text(
            "Signature",
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ComposingPage(
    padding: PaddingValues,
    addresses: List<MailAddress>,
    selectedId: String?,
    signature: String,
    saving: Boolean,
    fromOpen: Boolean,
    onFromOpenChange: (Boolean) -> Unit,
    onAddress: (String) -> Unit,
    onSignature: (String) -> Unit
) {
    PageBody(padding) {
        InfoBanner(
            icon = Icons.Rounded.Edit,
            title = "Compose defaults",
            text = "Choose the sender used for new mail and add a signature to outgoing messages."
        )
        if (addresses.isNotEmpty()) {
            SettingsGroup("Sending address") {
                ExposedDropdownMenuBox(
                    expanded = fromOpen,
                    onExpandedChange = onFromOpenChange,
                    modifier = Modifier.background(settingsPanelColor())
                ) {
                    OutlinedTextField(
                        value = addresses.firstOrNull { it.id == selectedId }?.address ?: "Default sender",
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(fromOpen) },
                        label = { Text("Default sender") },
                        shape = MaterialTheme.shapes.large,
                        modifier = Modifier.fillMaxWidth().padding(16.dp).menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable)
                    )
                    ExposedDropdownMenu(expanded = fromOpen, onDismissRequest = { onFromOpenChange(false) }) {
                        addresses.forEach { address ->
                            DropdownMenuItem({ Text(address.address) }, onClick = { onAddress(address.id) })
                        }
                    }
                }
            }
        }
        SettingsGroup("Signature") {
            OutlinedTextField(
                signature, onSignature,
                Modifier.fillMaxWidth().background(settingsPanelColor()).padding(16.dp),
                enabled = !saving,
                minLines = 4,
                maxLines = 8,
                label = { Text("Email signature") },
                placeholder = { Text("Sent from QuickInbox") },
                supportingText = { Text("${signature.length}/1000") },
                shape = MaterialTheme.shapes.large
            )
        }
        Text(
            if (saving) "Saving your signature…" else "Your signature is added to outgoing messages. Tap Save to keep your changes.",
            modifier = Modifier.padding(horizontal = 4.dp),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun PrivacyPage(
    padding: PaddingValues,
    remoteImages: Boolean,
    appLockState: dev.anuz.quickinbox.data.AppLockState,
    onAppLock: (Boolean) -> Unit,
    onRemoteImages: (Boolean) -> Unit
) {
    PageBody(padding) {
        InfoBanner(
            icon = Icons.Rounded.Shield,
            title = "Private by default",
            text = "Protect your inbox when you leave the app and control externally hosted message content."
        )
        SettingsGroup("App access") {
            SwitchRow(
                title = "App Lock",
                supporting = if (appLockState.isAvailable || appLockState.isEnabled) {
                    "Require biometrics or your screen lock when returning to QuickInbox."
                } else {
                    "Set up biometrics or a screen lock in Android Settings first."
                },
                checked = appLockState.isEnabled,
                enabled = appLockState.isAvailable || appLockState.isEnabled,
                onCheckedChange = onAppLock
            )
            appLockState.errorMessage?.let { message ->
                Row(
                    Modifier.fillMaxWidth().background(settingsPanelColor()).padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        Icons.Rounded.Warning,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error
                    )
                    Text(
                        message,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
        Text(
            "When enabled, QuickInbox hides message content after you leave the app and asks you to authenticate when you return.",
            modifier = Modifier.padding(horizontal = 4.dp),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        SettingsGroup("Message content") {
            SwitchRow(
                title = "Load remote images",
                supporting = "Automatically fetch externally hosted images when opening mail.",
                checked = remoteImages,
                onCheckedChange = onRemoteImages
            )
        }
        Text(
            "Remote images can let a sender know when and where a message was opened. You can still load them for individual messages.",
            modifier = Modifier.padding(horizontal = 4.dp),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun DevicesPage(
    padding: PaddingValues,
    devices: List<DeviceSession>,
    loading: Boolean,
    onRevoke: (DeviceSession) -> Unit
) {
    PageBody(padding) {
        InfoBanner(
            icon = Icons.Rounded.Devices,
            title = "Account access",
            text = "Review devices signed in to this QuickInbox server and revoke sessions you no longer recognize."
        )
        SettingsGroup("Devices with account access") {
            if (loading && devices.isEmpty()) {
                LoadingPanel("Loading devices…")
            } else if (devices.isEmpty()) {
                EmptyPanel(Icons.Rounded.Devices, "No connected devices", "No active device sessions were returned by your server.")
            } else {
                devices.forEach { device ->
                    Column(
                        Modifier.fillMaxWidth().background(settingsPanelColor()).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            TonalIcon(if (device.devicePlatform?.contains("ios", true) == true) Icons.Rounded.PhoneIphone else Icons.Rounded.Devices)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(device.deviceName ?: "Unknown device", style = MaterialTheme.typography.titleMedium)
                                Text(
                                    device.devicePlatform?.replaceFirstChar { it.uppercase() }.orEmpty().ifBlank { "Unknown platform" },
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        if (device.isCurrent) {
                            StatusBadge("This device")
                        } else {
                            OutlinedButton(
                                onClick = { onRevoke(device) },
                                modifier = Modifier.align(Alignment.End),
                                shape = MaterialTheme.shapes.large,
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) { Text("Revoke access") }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ConnectionPage(
    padding: PaddingValues,
    origin: String?,
    onDisconnect: () -> Unit,
    onRemoveLocal: () -> Unit
) {
    PageBody(padding) {
        InfoBanner(
            icon = Icons.Rounded.Dns,
            title = "Server connection",
            text = "Your mail remains connected through this QuickInbox server and its current device session."
        )
        SettingsGroup("Server") {
            InfoRow(Icons.Rounded.Storage, "Connected server", origin ?: "Unknown")
            InfoRow(Icons.Rounded.Lock, "Transport", "Secure HTTPS connection")
        }
        Surface(
            shape = MaterialTheme.shapes.extraLarge,
            color = settingsPanelColor()
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(Icons.Rounded.PhonelinkErase, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Session & local data", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                }
                Text(
                    "Disconnecting revokes this session. Removing local data only signs out this phone without contacting the server.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Button(
                    onDisconnect, Modifier.fillMaxWidth().heightIn(min = 52.dp),
                    shape = MaterialTheme.shapes.large,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error,
                        contentColor = MaterialTheme.colorScheme.onError
                    )
                ) {
                    Icon(Icons.AutoMirrored.Rounded.Logout, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Disconnect this device")
                }
                TextButton(onRemoveLocal, Modifier.fillMaxWidth()) {
                    Icon(Icons.Rounded.DeleteOutline, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Remove local data only")
                }
            }
        }
    }
}

@Composable
private fun SupportPage(padding: PaddingValues) {
    val context = LocalContext.current
    PageBody(padding) {
        InfoBanner(
            icon = Icons.AutoMirrored.Rounded.HelpOutline,
            title = "How can we help?",
            text = "Questions, feedback, and bug reports are welcome. Choose the channel that works best for you."
        )
        SettingsGroup("Get help") {
            ActionRow("Email support", "Open your mail app", Icons.Rounded.Email) {
                context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:quickinbox-support@quivren.com")))
            }
            ActionRow("Report an issue", "Open the GitHub issue tracker", Icons.Rounded.BugReport) {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/anuzsubedi/quickinbox-mobile/issues")))
            }
        }
        SettingsGroup("Troubleshooting") {
            InfoRow(Icons.Rounded.Info, "When reporting a problem", "Include what you expected and what happened")
        }
    }
}

@Composable
private fun ActionRow(title: String, supporting: String, icon: ImageVector, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().background(settingsPanelColor()).clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TonalIcon(icon)
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Medium)
            Text(supporting, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Icon(Icons.AutoMirrored.Rounded.OpenInNew, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun InfoBanner(icon: ImageVector, title: String, text: String) {
    val colors = MaterialTheme.colorScheme
    Surface(shape = MaterialTheme.shapes.extraLarge, color = colors.primaryContainer) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Surface(
                modifier = Modifier.size(44.dp),
                shape = MaterialTheme.shapes.large,
                color = colors.primary
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(icon, contentDescription = null, tint = colors.onPrimary)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onPrimaryContainer,
                    modifier = Modifier.semantics { heading() }
                )
                Text(text, style = MaterialTheme.typography.bodyMedium, color = colors.onPrimaryContainer)
            }
        }
    }
}

@Composable
private fun TonalIcon(icon: ImageVector) {
    Surface(
        modifier = Modifier.size(40.dp),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceContainerHigh
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun InfoRow(icon: ImageVector, title: String, value: String) {
    Row(
        Modifier.fillMaxWidth().background(settingsPanelColor()).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TonalIcon(icon)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(title, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun SwitchRow(
    title: String,
    supporting: String,
    checked: Boolean,
    enabled: Boolean = true,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        Modifier.fillMaxWidth().background(settingsPanelColor())
            .toggleable(value = checked, enabled = enabled, role = Role.Switch, onValueChange = onCheckedChange).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
            Text(supporting, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(checked = checked, enabled = enabled, onCheckedChange = null)
    }
}

@Composable
private fun StatusBadge(label: String) {
    Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.tertiaryContainer) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onTertiaryContainer,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun LoadingPanel(label: String) {
    Row(
        Modifier.fillMaxWidth().background(settingsPanelColor()).padding(24.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
        Spacer(Modifier.width(12.dp))
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun EmptyPanel(icon: ImageVector, title: String, text: String) {
    Column(
        Modifier.fillMaxWidth().background(settingsPanelColor()).padding(horizontal = 24.dp, vertical = 30.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        TonalIcon(icon)
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
            text,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun SectionLabel(title: String) {
    Text(
        title,
        Modifier.padding(horizontal = 12.dp).semantics { heading() },
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontWeight = FontWeight.SemiBold
    )
}

@Composable
private fun settingsPanelColor(): Color = MaterialTheme.colorScheme.surfaceContainerLow

private suspend fun disconnect(
    container: AppContainer,
    revokeOnServer: Boolean,
    devices: List<DeviceSession>
): String? {
    var revocationError: Exception? = null
    if (revokeOnServer) {
        try {
            withContext(Dispatchers.IO) {
                val current = devices.firstOrNull { it.isCurrent }
                if (current != null) container.api.revokeDevice(current.id)
                else container.api.logout(container.credentialStore, revokeCurrentDevice = true)
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            revocationError = error
        }
    }
    try {
        withContext(Dispatchers.IO) { container.api.logout(container.credentialStore, revokeCurrentDevice = false) }
    } catch (error: CancellationException) {
        throw error
    } catch (error: Exception) {
        revocationError = revocationError ?: error
    }
    container.preferences.clear()
    container.mailboxCache.clearAll()
    return if (revokeOnServer && revocationError != null) {
        "This phone was disconnected locally, but the server could not confirm revocation. Revoke it from QuickInbox on the web."
    } else null
}

private suspend fun <T> callOrDefault(default: T, block: suspend () -> T): T =
    try {
        block()
    } catch (error: CancellationException) {
        throw error
    } catch (_: Exception) {
        default
    }
