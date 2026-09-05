package dev.anuz.quickinbox.ui.thread

import android.content.Intent
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Reply
import androidx.compose.material.icons.automirrored.outlined.ReplyAll
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.outlined.MarkEmailUnread
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.rounded.Archive
import androidx.compose.material.icons.rounded.AttachFile
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material.icons.rounded.MarkEmailRead
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.RestoreFromTrash
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Unarchive
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconToggleButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.draw.scale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import dev.anuz.quickinbox.data.AppPreferences
import dev.anuz.quickinbox.domain.EmailAttachment
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.ThreadMessage
import dev.anuz.quickinbox.domain.ThreadSummary
import dev.anuz.quickinbox.domain.formatBytes
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics
import dev.anuz.quickinbox.ui.components.SenderTile
import dev.anuz.quickinbox.ui.compose.ComposeMode
import dev.anuz.quickinbox.ui.theme.LocalQuickInboxDarkTheme
import dev.anuz.quickinbox.ui.theme.QuickInboxMotion
import java.text.DateFormat
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThreadScreen(
    state: ThreadUiState,
    summary: ThreadSummary?,
    preferences: AppPreferences,
    onBack: () -> Unit,
    onCompose: (ComposeMode) -> Unit,
    onAction: (MailAction) -> Unit,
    onDownload: (ThreadMessage, EmailAttachment) -> Unit,
    onOpenedAttachmentConsumed: () -> Unit
) {
    val context = LocalContext.current
    val messages = state.chronologicalMessages
    val latest = messages.lastOrNull()
    val subject = state.detail?.subject ?: summary?.subject ?: "Conversation"
    val actionsEnabled = state.detail != null && !state.isLoading && state.actionInProgress == null
    val readerScroll = rememberScrollState()
    var menuExpanded by remember { mutableStateOf(false) }
    var confirmPermanentDelete by remember { mutableStateOf(false) }

    fun replyTo(message: ThreadMessage, replyAll: Boolean = false) {
        onCompose(
            ComposeMode.Reply(
                messageId = message.id,
                recipient = if (message.direction == "inbound") message.fromAddress else message.toAddress,
                subject = replySubject(subject),
                recipientName = message.fromName.takeIf { message.direction == "inbound" },
                fromAddressHint = if (message.direction == "inbound") message.toAddress else message.fromAddress,
                originalTo = message.toAddress,
                originalCc = message.ccAddress,
                replyAll = replyAll
            )
        )
    }

    fun forward(message: ThreadMessage) {
        onCompose(
            ComposeMode.Forward.Message(
                messageId = message.id,
                subject = forwardSubject(subject),
                attachmentCount = message.attachments.size,
                fromAddressHint = if (message.direction == "inbound") message.toAddress else message.fromAddress
            )
        )
    }

    fun forwardAll() {
        val threadId = state.detail?.threadId?.takeIf { it.isNotBlank() }
            ?: summary?.threadId?.takeIf { it.isNotBlank() }
            ?: return
        onCompose(
            ComposeMode.Forward.Thread(
                threadId = threadId,
                subject = forwardSubject(subject),
                messageCount = messages.size,
                attachmentCount = messages.sumOf { it.attachments.size },
                fromAddressHint = latest?.let {
                    if (it.direction == "inbound") it.toAddress else it.fromAddress
                }
            )
        )
    }

    LaunchedEffect(state.openedAttachment) {
        val opened = state.openedAttachment ?: return@LaunchedEffect
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", opened.file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, opened.contentType.ifBlank { "*/*" })
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        runCatching { context.startActivity(intent) }
        onOpenedAttachmentConsumed()
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.surface,
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    ReaderChromeButton(
                        icon = Icons.AutoMirrored.Rounded.ArrowBack,
                        description = "Back to mailbox",
                        onClick = onBack,
                        modifier = Modifier.padding(start = 8.dp)
                            .background(MaterialTheme.colorScheme.surfaceContainerLow, MaterialTheme.shapes.large)
                    )
                },
                actions = {
                    Surface(
                        modifier = Modifier.padding(end = 12.dp),
                        shape = MaterialTheme.shapes.extraLarge,
                        color = MaterialTheme.colorScheme.surfaceContainerLow
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            if (!state.isTrashed) {
                                ReaderChromeButton(
                                    icon = if (state.isArchived) Icons.Rounded.Unarchive else Icons.Rounded.Archive,
                                    description = if (state.isArchived) "Move to inbox" else "Archive",
                                    enabled = actionsEnabled,
                                    onClick = { onAction(if (state.isArchived) MailAction.Unarchive else MailAction.Archive) }
                                )
                                ReaderChromeButton(
                                    icon = Icons.Rounded.Delete,
                                    description = "Move to trash",
                                    enabled = actionsEnabled,
                                    onClick = { onAction(MailAction.Trash) }
                                )
                            } else {
                                ReaderChromeButton(
                                    icon = Icons.Rounded.RestoreFromTrash,
                                    description = "Restore",
                                    enabled = actionsEnabled,
                                    onClick = { onAction(MailAction.Restore) }
                                )
                            }
                            ReaderChromeButton(
                                icon = if (state.isRead) Icons.Outlined.MarkEmailUnread else Icons.Rounded.MarkEmailRead,
                                description = if (state.isRead) "Mark as unread" else "Mark as read",
                                enabled = actionsEnabled,
                                onClick = { onAction(if (state.isRead) MailAction.Unread else MailAction.Read) }
                            )
                            Box {
                                ReaderChromeButton(
                                    icon = Icons.Rounded.MoreVert,
                                    description = "More conversation actions",
                                    enabled = actionsEnabled,
                                    onClick = { menuExpanded = true }
                                )
                                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                                    if (latest != null) {
                                        DropdownMenuItem(
                                            text = { Text("Reply all") },
                                            enabled = actionsEnabled,
                                            leadingIcon = { Icon(Icons.AutoMirrored.Outlined.ReplyAll, null) },
                                            onClick = { menuExpanded = false; replyTo(latest, replyAll = true) }
                                        )
                                    }
                                    if (state.isTrashed) {
                                        DropdownMenuItem(
                                            text = { Text("Delete forever", color = MaterialTheme.colorScheme.error) },
                                            enabled = actionsEnabled,
                                            leadingIcon = { Icon(Icons.Rounded.Delete, null, tint = MaterialTheme.colorScheme.error) },
                                            onClick = { menuExpanded = false; confirmPermanentDelete = true }
                                        )
                                    }
                                }
                            }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    actionIconContentColor = MaterialTheme.colorScheme.onSurfaceVariant
                )
            )
        },
        bottomBar = {
            if (latest != null) {
                ThreadReplyBar(
                    enabled = actionsEnabled,
                    onForwardAll = if (state.isTrashed) null else ::forwardAll,
                    onReply = { replyTo(latest) }
                )
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize()) {
            when {
                state.isLoading && state.detail == null -> Box(
                    Modifier.fillMaxSize().padding(padding),
                    contentAlignment = Alignment.Center
                ) { CircularProgressIndicator() }
                state.errorMessage != null && state.detail == null -> Box(
                    Modifier.fillMaxSize().padding(padding).padding(32.dp),
                    contentAlignment = Alignment.Center
                ) { Text(state.errorMessage, color = MaterialTheme.colorScheme.error) }
                else -> Column(
                    Modifier.fillMaxSize().padding(padding).verticalScroll(readerScroll)
                ) {
                    ThreadSubjectHeader(
                        subject = subject,
                        mailboxLabel = when {
                            state.isTrashed -> "Trash"
                            state.isArchived -> "Archive"
                            else -> "Inbox"
                        },
                        messageCount = messages.size,
                        isStarred = state.isStarred,
                        starEnabled = actionsEnabled,
                        onToggleStar = { onAction(if (state.isStarred) MailAction.Unstar else MailAction.Star) }
                    )
                    state.savedDataMessage?.let { message ->
                        Row(
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            if (state.isRefreshing) {
                                CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp)
                            }
                            Text(
                                message,
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    state.errorMessage?.let {
                        Text(it, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp), color = MaterialTheme.colorScheme.error)
                    }
                    if (messages.isNotEmpty()) {
                        Column(
                            modifier = Modifier.padding(horizontal = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            messages.forEachIndexed { index, message ->
                                ThreadMessageCard(
                                    message = message,
                                    first = index == 0,
                                    last = index == messages.lastIndex,
                                    initiallyExpanded = index == messages.lastIndex,
                                    showRemoteImagesByDefault = preferences.showRemoteImagesByDefault,
                                    downloadingIds = state.downloadingIds,
                                    onReply = { replyTo(message) },
                                    onForward = { forward(message) },
                                    onDownload = { onDownload(message, it) }
                                )
                            }
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }
            }
        }
    }

    if (confirmPermanentDelete) {
        AlertDialog(
            onDismissRequest = { confirmPermanentDelete = false },
            icon = { Icon(Icons.Rounded.Delete, contentDescription = null) },
            title = { Text("Delete conversation forever?") },
            text = { Text("This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmPermanentDelete = false
                    onAction(MailAction.Delete)
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { confirmPermanentDelete = false }) { Text("Cancel") }
            }
        )
    }
}

/** Shared touch target and tonal treatment for the reader toolbar. */
@Composable
private fun ReaderChromeButton(
    icon: ImageVector,
    description: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    val haptics = rememberQuickInboxHaptics()
    IconButton(
        onClick = { haptics.tap(); onClick() },
        enabled = enabled,
        modifier = modifier.size(48.dp).clip(MaterialTheme.shapes.large)
    ) {
        Icon(icon, contentDescription = description, modifier = Modifier.size(22.dp))
    }
}

@Composable
private fun ThreadSubjectHeader(
    subject: String,
    mailboxLabel: String,
    messageCount: Int,
    isStarred: Boolean,
    starEnabled: Boolean,
    onToggleStar: () -> Unit
) {
    val colors = MaterialTheme.colorScheme
    Column(
        modifier = Modifier.fillMaxWidth().padding(start = 20.dp, end = 12.dp, bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = buildString {
                    append(mailboxLabel)
                    if (messageCount > 0) append(" · $messageCount ${if (messageCount == 1) "message" else "messages"}")
                },
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.labelLarge,
                color = colors.onSurfaceVariant
            )
            IconToggleButton(
                checked = isStarred,
                onCheckedChange = { onToggleStar() },
                enabled = starEnabled
            ) {
                Icon(
                    if (isStarred) Icons.Rounded.Star else Icons.Outlined.StarOutline,
                    contentDescription = if (isStarred) "Remove star" else "Add star"
                )
            }
        }
        Text(
            text = subject.ifBlank { "(No subject)" },
            modifier = Modifier.padding(end = 8.dp).semantics { heading() },
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Medium,
            color = colors.onSurface
        )
    }
}

@Composable
private fun ThreadMessageCard(
    message: ThreadMessage,
    first: Boolean,
    last: Boolean,
    initiallyExpanded: Boolean,
    showRemoteImagesByDefault: Boolean,
    downloadingIds: Set<String>,
    onReply: () -> Unit,
    onForward: () -> Unit,
    onDownload: (EmailAttachment) -> Unit
) {
    var expanded by remember(message.id) { mutableStateOf(initiallyExpanded) }
    var showDetails by remember(message.id) { mutableStateOf(false) }
    var menuExpanded by remember { mutableStateOf(false) }
    val sender = message.senderDisplayName.ifBlank { "Unknown sender" }
    val time = message.createdAt?.let(::messageTimestamp).orEmpty()
    val recipient = if (message.direction.equals("inbound", ignoreCase = true)) "to me"
    else message.toAddress.takeIf { it.isNotBlank() }?.let { "to $it" } ?: "sent message"

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(
                animationSpec = tween(
                    durationMillis = QuickInboxMotion.DurationMedium,
                    easing = QuickInboxMotion.Standard
                )
            )
            .clickable(enabled = !expanded) { expanded = true },
        shape = RoundedCornerShape(
            topStart = if (first) 16.dp else 0.dp,
            topEnd = if (first) 16.dp else 0.dp,
            bottomStart = if (last) 16.dp else 0.dp,
            bottomEnd = if (last) 16.dp else 0.dp
        ),
        color = conversationSheetColor()
    ) {
        Column(Modifier.padding(bottom = 14.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        expanded = !expanded
                        if (!expanded) showDetails = false
                    }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.Top
            ) {
                SenderTile(name = sender, size = 44.dp)
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = sender,
                            modifier = Modifier.weight(1f),
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (time.isNotBlank()) {
                            Spacer(Modifier.width(6.dp))
                            Text(
                                text = time,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                    if (expanded) {
                        Row(
                            modifier = Modifier.clickable { showDetails = !showDetails }.padding(vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(recipient, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Icon(
                                if (showDetails) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
                                contentDescription = if (showDetails) "Hide message details" else "Show message details",
                                modifier = Modifier.size(18.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    } else {
                        Text(
                            message.bodyText?.take(140) ?: message.subject,
                            modifier = Modifier.padding(top = 2.dp),
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
                if (expanded) {
                    Box {
                        IconButton(onClick = { menuExpanded = true }) {
                            Icon(Icons.Rounded.MoreVert, contentDescription = "Message actions")
                        }
                        DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                            DropdownMenuItem(
                                text = { Text("Reply") },
                                leadingIcon = { Icon(Icons.AutoMirrored.Outlined.Reply, null) },
                                onClick = { menuExpanded = false; onReply() }
                            )
                            DropdownMenuItem(
                                text = { Text("Forward") },
                                leadingIcon = {
                                    Icon(
                                        Icons.AutoMirrored.Outlined.Reply,
                                        null,
                                        modifier = Modifier.scale(scaleX = -1f, scaleY = 1f)
                                    )
                                },
                                onClick = { menuExpanded = false; onForward() }
                            )
                        }
                    }
                } else {
                    IconButton(onClick = { expanded = true }) {
                        Icon(Icons.Rounded.ExpandMore, contentDescription = "Expand message")
                    }
                }
            }

            if (expanded) {
                if (showDetails) {
                    Box(Modifier.padding(horizontal = 16.dp)) {
                        MessageDetails(message = message, sender = sender)
                    }
                }
                Spacer(Modifier.height(22.dp))
                val htmlBody = message.bodyHtml?.trim().orEmpty()
                val plainText = message.bodyText?.trim().orEmpty()
                when {
                    htmlBody.isNotEmpty() && HtmlMessageSanitizer.hasVisibleContent(htmlBody) -> {
                        FormattedMessageBody(
                            html = htmlBody,
                            showRemoteImagesByDefault = showRemoteImagesByDefault
                        )
                    }
                    plainText.isNotEmpty() -> {
                        Box(Modifier.padding(horizontal = 16.dp)) {
                            PlainMessageBody(plainText)
                        }
                    }
                    message.attachments.isEmpty() -> {
                        Text(
                            "This message has no readable body.",
                            modifier = Modifier.padding(horizontal = 16.dp),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            style = MaterialTheme.typography.bodyLarge,
                            fontStyle = FontStyle.Italic
                        )
                    }
                }
                if (message.attachments.isNotEmpty()) {
                    Spacer(Modifier.height(18.dp))
                    Column(Modifier.padding(horizontal = 16.dp)) {
                        message.attachments.forEach { attachment ->
                            AttachmentRow(
                                attachment = attachment,
                                downloading = attachment.id in downloadingIds,
                                onDownload = { onDownload(attachment) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FormattedMessageBody(html: String, showRemoteImagesByDefault: Boolean) {
    var loadImages by remember(html) { mutableStateOf(showRemoteImagesByDefault) }
    var showQuotedHistory by remember(html) { mutableStateOf(false) }
    val parts = remember(html) { HtmlQuotedContentParser.split(html) }

    Column(
        modifier = Modifier.padding(horizontal = 6.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (HtmlMessageSanitizer.containsRemoteImages(html) && !loadImages) {
            FilledTonalButton(
                onClick = { loadImages = true },
                modifier = Modifier.semantics {
                    contentDescription = "Show images. Loads remote images that may allow the sender to track this open"
                }
            ) {
                Icon(Icons.Rounded.Image, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Show images")
            }
        }
        HardenedHtmlView(html = parts.message, loadsRemoteImages = loadImages)
        parts.quotedHistory?.let { history ->
            TextButton(onClick = { showQuotedHistory = !showQuotedHistory }) {
                Icon(
                    if (showQuotedHistory) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
                    contentDescription = null
                )
                Spacer(Modifier.width(4.dp))
                Text(if (showQuotedHistory) "Hide quoted history" else "Show quoted history")
            }
            if (showQuotedHistory) HardenedHtmlView(html = history, loadsRemoteImages = loadImages)
        }
    }
}

@Composable
private fun PlainMessageBody(text: String) {
    var showQuotedHistory by remember(text) { mutableStateOf(false) }
    val parts = remember(text) { QuotedTextParser.split(text) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(parts.message, style = MaterialTheme.typography.bodyLarge)
        parts.quotedHistory?.let { history ->
            TextButton(onClick = { showQuotedHistory = !showQuotedHistory }) {
                Icon(
                    if (showQuotedHistory) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
                    contentDescription = null
                )
                Spacer(Modifier.width(4.dp))
                Text(if (showQuotedHistory) "Hide quoted history" else "Show quoted history")
            }
            if (showQuotedHistory) {
                Text(history, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun MessageDetails(message: ThreadMessage, sender: String) {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(top = 14.dp),
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHigh
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            DetailRow(
                label = "From",
                value = listOf(sender, message.fromAddress).filter { it.isNotBlank() }.joinToString(" · ")
            )
            DetailRow(label = "To", value = message.toAddress.ifBlank { "Not provided" })
            message.ccAddress?.takeIf { it.isNotBlank() }?.let { DetailRow(label = "Cc", value = it) }
            DetailRow(
                label = "Date",
                value = message.createdAt?.let {
                    DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(it)
                }.orEmpty().ifBlank { "Not provided" }
            )
            message.subject.takeIf { it.isNotBlank() }?.let { DetailRow(label = "Subject", value = it) }
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        Text(
            label,
            modifier = Modifier.width(64.dp),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(value, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun AttachmentRow(attachment: EmailAttachment, downloading: Boolean, onDownload: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).clickable(onClick = onDownload),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHigh
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.AttachFile, contentDescription = null)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(attachment.filename, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(formatBytes(attachment.sizeBytes), style = MaterialTheme.typography.bodySmall)
            }
            if (downloading) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
        }
    }
}

@Composable
private fun conversationSheetColor() = if (LocalQuickInboxDarkTheme.current) {
    MaterialTheme.colorScheme.surfaceContainerLow
} else {
    MaterialTheme.colorScheme.surfaceContainerLowest
}

private fun replySubject(subject: String): String =
    if (subject.startsWith("Re:", ignoreCase = true)) subject else "Re: $subject"

private val ForwardPrefix = Regex("""^\s*(fw|fwd)\s*(\[\d+])?\s*:""", RegexOption.IGNORE_CASE)

private fun forwardSubject(subject: String): String {
    val trimmed = subject.trim()
    return when {
        trimmed.isEmpty() -> "Fwd:"
        ForwardPrefix.containsMatchIn(trimmed) -> trimmed
        else -> "Fwd: $trimmed"
    }
}

private fun messageTimestamp(date: Date): String {
    val now = Calendar.getInstance()
    val value = Calendar.getInstance().apply { time = date }
    val isToday = now.get(Calendar.ERA) == value.get(Calendar.ERA) &&
        now.get(Calendar.YEAR) == value.get(Calendar.YEAR) &&
        now.get(Calendar.DAY_OF_YEAR) == value.get(Calendar.DAY_OF_YEAR)
    return if (isToday) DateFormat.getTimeInstance(DateFormat.SHORT).format(date)
    else DateFormat.getDateInstance(DateFormat.MEDIUM).format(date)
}
