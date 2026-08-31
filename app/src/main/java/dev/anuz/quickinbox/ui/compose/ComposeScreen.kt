package dev.anuz.quickinbox.ui.compose

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Reply
import androidx.compose.material.icons.automirrored.outlined.ReplyAll
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Forward
import androidx.compose.material.icons.automirrored.rounded.Reply
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.AttachFile
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.PeopleOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.domain.MailAddress
import dev.anuz.quickinbox.domain.EmailAddressPresentation
import dev.anuz.quickinbox.domain.formatBytes
import dev.anuz.quickinbox.ui.components.BorderlessTextField
import dev.anuz.quickinbox.ui.components.Pressable
import dev.anuz.quickinbox.ui.components.RuleDivider
import dev.anuz.quickinbox.ui.components.rememberQuickInboxHaptics
import dev.anuz.quickinbox.ui.theme.QuickInboxMotion

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ComposeScreen(
    mode: ComposeMode,
    state: ComposeUiState,
    onBack: () -> Unit,
    onTo: (List<String>) -> Unit,
    onCc: (List<String>) -> Unit,
    onBcc: (List<String>) -> Unit,
    onSubject: (String) -> Unit,
    onBody: (String) -> Unit,
    onFrom: (String) -> Unit,
    onIncludeOriginalAttachments: (Boolean) -> Unit,
    onSend: () -> Unit,
    onImport: (List<android.net.Uri>) -> Unit,
    onRemoveAttachment: (String) -> Unit
) {
    val hasCcBccContent = state.cc.isNotEmpty() || state.bcc.isNotEmpty()
    var showCcBcc by remember { mutableStateOf(hasCcBccContent) }
    var fromOpen by remember { mutableStateOf(false) }
    var replyMenuOpen by remember(mode) { mutableStateOf(false) }
    var replyAll by remember(mode) { mutableStateOf(false) }
    var metadataCollapsed by remember { mutableStateOf(false) }
    val haptics = rememberQuickInboxHaptics()
    val fieldsEnabled = !state.isLoadingDraft && !state.isSending
    val isReply = mode is ComposeMode.Reply
    val sendEnabled = fieldsEnabled && state.to.isNotEmpty() && when (mode) {
        is ComposeMode.Reply -> state.body.isNotBlank()
        is ComposeMode.Forward -> true
        else -> state.subject.isNotBlank() && state.body.isNotBlank() && state.selectedFromAddressId != null
    }

    LaunchedEffect(hasCcBccContent) {
        if (hasCcBccContent) showCcBcc = true
    }

    var lastError by remember { mutableStateOf(state.errorMessage) }
    LaunchedEffect(state.errorMessage) {
        val current = state.errorMessage
        if (current != null && current != lastError) haptics.reject()
        lastError = current
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        onImport(uris)
    }

    fun requestAttach() {
        if (!fieldsEnabled) return
        haptics.tap()
        picker.launch(arrayOf("*/*"))
    }

    fun requestSend() {
        if (state.isSending) return
        haptics.tap()
        onSend()
    }

    val showFromInToolbar = state.addresses.isNotEmpty() && state.selectedFromAddressId != null

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            ComposeHeader(
                onClose = onBack,
                showAttach = mode !is ComposeMode.Forward,
                attachEnabled = fieldsEnabled,
                onAttach = ::requestAttach,
                sendEnabled = sendEnabled,
                sending = state.isSending,
                onSend = ::requestSend
            )
        }
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .navigationBarsPadding()
                .imePadding()
        ) {
            Surface(
                modifier = Modifier.fillMaxSize(),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 0.dp
            ) {
                Column(Modifier.fillMaxSize()) {
                    AnimatedContent(
                        targetState = metadataCollapsed,
                        transitionSpec = {
                            (fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard))) togetherWith
                                fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) using
                                SizeTransform(clip = false)
                        },
                        label = "compose-metadata"
                    ) { collapsed ->
                        if (collapsed) {
                            ComposeMetadataSummary(
                                to = state.to,
                                subject = state.subject,
                                hasCcBcc = hasCcBccContent,
                                attachmentCount = state.attachments.size,
                                onExpand = { metadataCollapsed = false }
                            )
                        } else {
                            Column(
                                Modifier
                                    .fillMaxWidth()
                                    .heightIn(max = 360.dp)
                                    .verticalScroll(rememberScrollState())
                            ) {
                                if (showFromInToolbar) {
                                    ComposeFromRow(
                                        addresses = state.addresses,
                                        selectedId = state.selectedFromAddressId,
                                        expanded = fromOpen,
                                        onExpandedChange = { fromOpen = it },
                                        onSelect = onFrom,
                                        enabled = fieldsEnabled
                                    )
                                    RuleDivider()
                                } else if (mode is ComposeMode.Reply && !mode.fromAddressHint.isNullOrBlank()) {
                                    ComposeMetadataRow(label = "From", value = mode.fromAddressHint)
                                    RuleDivider()
                                } else if (mode is ComposeMode.Forward && !mode.fromAddressHint.isNullOrBlank()) {
                                    ComposeMetadataRow(label = "From", value = mode.fromAddressHint.orEmpty())
                                    RuleDivider()
                                }
                                RecipientChipField(
                                    label = "To",
                                    recipients = state.to,
                                    onRecipientsChange = onTo,
                                    enabled = fieldsEnabled,
                                    recipientNames = (mode as? ComposeMode.Reply)?.let { reply ->
                                        reply.recipientName?.let { mapOf(reply.recipient to it) }
                                    }
                                        .orEmpty(),
                                    leadingIcon = when (mode) {
                                        is ComposeMode.Reply -> {
                                            {
                                                ReplyModeSelector(
                                                    replyAll = replyAll,
                                                    expanded = replyMenuOpen,
                                                    enabled = fieldsEnabled,
                                                    onExpandedChange = { replyMenuOpen = it },
                                                    onReply = {
                                                        replyAll = false
                                                        onTo(listOf(EmailAddressPresentation.addressOnly(mode.recipient)))
                                                        onCc(emptyList())
                                                        onBcc(emptyList())
                                                    },
                                                    onReplyAll = {
                                                        replyAll = true
                                                        val self = state.addresses.map { it.address.lowercase() }.toSet()
                                                        val primary = EmailAddressPresentation.addressOnly(mode.recipient)
                                                        val extras = (mode.originalTo.split(',') + mode.originalCc.orEmpty().split(','))
                                                            .map(EmailAddressPresentation::addressOnly)
                                                            .map(String::trim)
                                                            .filter { it.isNotEmpty() && it.lowercase() !in self && !it.equals(primary, true) }
                                                            .distinctBy(String::lowercase)
                                                        onTo(listOf(primary))
                                                        onCc(extras)
                                                        showCcBcc = extras.isNotEmpty()
                                                    }
                                                )
                                            }
                                        }
                                        is ComposeMode.Forward -> {
                                            {
                                                Icon(
                                                    Icons.AutoMirrored.Rounded.Forward,
                                                    contentDescription = "Forward to",
                                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                                    modifier = Modifier.size(20.dp)
                                                )
                                            }
                                        }
                                        else -> null
                                    },
                                    trailing = if (!showCcBcc && !hasCcBccContent) {
                                        {
                                            TextButton(
                                                onClick = { showCcBcc = true },
                                                enabled = fieldsEnabled,
                                                modifier = Modifier.heightIn(min = 40.dp)
                                            ) {
                                                Icon(
                                                    Icons.Rounded.PeopleOutline,
                                                    contentDescription = null,
                                                    modifier = Modifier.size(16.dp)
                                                )
                                                Spacer(Modifier.width(4.dp))
                                                Text("Cc/Bcc", style = MaterialTheme.typography.labelLarge)
                                            }
                                        }
                                    } else null
                                )
                                AnimatedVisibility(
                                    visible = showCcBcc,
                                    enter = fadeIn(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)) +
                                        expandVertically(tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard)),
                                    exit = fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate)) +
                                        shrinkVertically(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Decelerate))
                                ) {
                                    Column {
                                        RecipientChipField("Cc", state.cc, onCc, enabled = fieldsEnabled)
                                        RecipientChipField("Bcc", state.bcc, onBcc, enabled = fieldsEnabled)
                                    }
                                }
                                if (mode is ComposeMode.Reply || mode is ComposeMode.Forward) {
                                    ReadOnlySubject(state.subject)
                                } else {
                                    ComposeFieldRow(
                                        value = state.subject,
                                        onValueChange = onSubject,
                                        label = "Subject",
                                        enabled = fieldsEnabled
                                    )
                                }
                                RuleDivider()

                                if (state.attachments.isNotEmpty()) {
                                    AttachmentChipRow(
                                        attachments = state.attachments,
                                        onRemove = onRemoveAttachment,
                                        enabled = fieldsEnabled
                                    )
                                }
                            }
                        }
                    }

                    MessageCanvas(
                        value = state.body,
                        onValueChange = onBody,
                        enabled = fieldsEnabled,
                        onFocused = {},
                        placeholder = when (mode) {
                            is ComposeMode.Reply -> "Write a reply"
                            is ComposeMode.Forward -> "Add a message"
                            else -> "Write your message"
                        },
                        originalIncluded = mode is ComposeMode.Forward,
                        originalMessageCount = (mode as? ComposeMode.Forward)?.messageCount ?: 0,
                        originalAttachmentCount = (mode as? ComposeMode.Forward)?.attachmentCount ?: 0,
                        includeOriginalAttachments = state.includeOriginalAttachments,
                        onIncludeOriginalAttachments = onIncludeOriginalAttachments,
                        modifier = Modifier.weight(1f)
                    )

                    ComposeStatusArea(
                        attachmentMessage = state.attachmentMessage,
                        errorMessage = state.errorMessage,
                        loading = state.isLoadingDraft || state.isLoadingAddresses || state.isImporting,
                        loadingLabel = when {
                            state.isLoadingDraft -> "Loading draft…"
                            state.isLoadingAddresses -> "Loading sending addresses…"
                            state.isImporting -> "Attaching files…"
                            else -> "Working…"
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun ReplyModeSelector(
    replyAll: Boolean,
    expanded: Boolean,
    enabled: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onReply: () -> Unit,
    onReplyAll: () -> Unit
) {
    Box {
        Pressable(
            onClick = { onExpandedChange(true) },
            enabled = enabled,
            role = Role.Button,
            onClickLabel = "Choose reply type",
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.height(48.dp)
        ) {
            Row(
                modifier = Modifier.height(48.dp).padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    if (replyAll) Icons.AutoMirrored.Outlined.ReplyAll else Icons.AutoMirrored.Outlined.Reply,
                    contentDescription = if (replyAll) "Reply all" else "Reply",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp)
                )
                Icon(
                    Icons.Rounded.ExpandMore,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { onExpandedChange(false) }) {
            DropdownMenuItem(
                text = { Text("Reply") },
                leadingIcon = { Icon(Icons.AutoMirrored.Outlined.Reply, contentDescription = null) },
                trailingIcon = { if (!replyAll) Icon(Icons.Rounded.Check, contentDescription = null) },
                onClick = {
                    onReply()
                    onExpandedChange(false)
                }
            )
            DropdownMenuItem(
                text = { Text("Reply all") },
                leadingIcon = { Icon(Icons.AutoMirrored.Outlined.ReplyAll, contentDescription = null) },
                trailingIcon = { if (replyAll) Icon(Icons.Rounded.Check, contentDescription = null) },
                onClick = {
                    onReplyAll()
                    onExpandedChange(false)
                }
            )
        }
    }
}

@Composable
private fun ComposeHeader(
    onClose: () -> Unit,
    showAttach: Boolean,
    attachEnabled: Boolean,
    onAttach: () -> Unit,
    sendEnabled: Boolean,
    sending: Boolean,
    onSend: () -> Unit
) {
    Column(Modifier.fillMaxWidth().statusBarsPadding()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onClose) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back")
            }
            Spacer(Modifier.weight(1f))
            if (showAttach) {
                IconButton(onClick = onAttach, enabled = attachEnabled) {
                    Icon(Icons.Rounded.AttachFile, contentDescription = "Attach files")
                }
            }
            SendAction(
                enabled = sendEnabled,
                sending = sending,
                onSend = onSend
            )
        }
    }
}

@Composable
private fun SendAction(
    enabled: Boolean,
    sending: Boolean,
    onSend: () -> Unit
) {
    IconButton(onClick = onSend, enabled = enabled) {
        AnimatedContent(
            targetState = sending,
            transitionSpec = {
                fadeIn(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Standard)) togetherWith
                    fadeOut(tween(QuickInboxMotion.DurationShort, easing = QuickInboxMotion.Standard))
            },
            label = "send-state"
        ) { isSending ->
            if (isSending) {
                CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
            } else {
                Icon(
                    Icons.AutoMirrored.Rounded.Send,
                    contentDescription = "Send",
                    tint = if (enabled) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                )
            }
        }
    }
}

@Composable
private fun ComposeFromRow(
    addresses: List<MailAddress>,
    selectedId: String?,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onSelect: (String) -> Unit,
    enabled: Boolean
) {
    val selectedAddress = addresses.firstOrNull { it.id == selectedId }?.address ?: "From"
    Box(Modifier.fillMaxWidth()) {
        Pressable(
            onClick = { onExpandedChange(!expanded) },
            enabled = enabled,
            role = Role.Button,
            onClickLabel = "Change sending address",
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .height(56.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text("From", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    selectedAddress,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    Icons.Rounded.ExpandMore,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { onExpandedChange(false) }) {
            addresses.forEach { address ->
                DropdownMenuItem(
                    text = {
                        Text(
                            address.address,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    },
                    trailingIcon = {
                        if (address.id == selectedId) {
                            Icon(
                                Icons.Rounded.Check,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    },
                    onClick = {
                        onSelect(address.id)
                        onExpandedChange(false)
                    }
                )
            }
        }
    }
}

/**
 * Compact single-line stand-in for the metadata form, shown once the writer starts on the
 * body so the message gets the full height of the screen. Tapping it re-expands the form.
 */
@Composable
private fun ComposeMetadataSummary(
    to: List<String>,
    subject: String,
    hasCcBcc: Boolean,
    attachmentCount: Int,
    onExpand: () -> Unit
) {
    Column(Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onExpand)
                .heightIn(min = 64.dp)
                .padding(horizontal = 20.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        to.joinToString(", ").ifBlank { "No recipients" },
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                    if (hasCcBcc) {
                        Text(
                            "  Cc/Bcc",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1
                        )
                    }
                }
                Text(
                    subject.ifBlank { "(No subject)" },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (attachmentCount > 0) {
                Icon(
                    Icons.Rounded.AttachFile,
                    contentDescription = "$attachmentCount attachments",
                    modifier = Modifier.size(18.dp).padding(end = 2.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Icon(
                Icons.Rounded.ExpandMore,
                contentDescription = "Show recipients and subject",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        HorizontalDivider(
            Modifier.padding(horizontal = 20.dp),
            thickness = 1.dp,
            color = MaterialTheme.colorScheme.outlineVariant
        )
    }
}

@Composable
private fun ComposeMetadataRow(label: String, value: String) {
    Column(Modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .padding(horizontal = 20.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.width(64.dp)
            )
            Text(
                value,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun ReadOnlySubject(value: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .padding(horizontal = 20.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Text(
            value,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun ComposeFieldRow(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    enabled: Boolean = true
) {
    BorderlessTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .padding(horizontal = 8.dp),
        placeholder = label,
        enabled = enabled,
        singleLine = true,
        textStyle = MaterialTheme.typography.bodyLarge
    )
}

@Composable
private fun AttachmentChipRow(
    attachments: List<ComposeAttachment>,
    onRemove: (String) -> Unit,
    enabled: Boolean
) {
    Column(Modifier.fillMaxWidth()) {
        Text(
            "ATTACHMENTS",
            modifier = Modifier.padding(start = 20.dp, top = 8.dp, bottom = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.Bold
        )
        attachments.forEach { attachment ->
            AttachmentSlip(
                attachment = attachment,
                onRemove = { onRemove(attachment.id) },
                enabled = enabled
            )
        }
    }
}

@Composable
private fun AttachmentSlip(
    attachment: ComposeAttachment,
    onRemove: () -> Unit,
    enabled: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(14.dp))
            .padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            Icons.Rounded.AttachFile,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                attachment.filename,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                formatBytes(attachment.byteCount),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        IconButton(
            onClick = onRemove,
            enabled = enabled,
            modifier = Modifier.size(36.dp)
        ) {
            Icon(
                Icons.Rounded.Close,
                contentDescription = "Remove ${attachment.filename}",
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

@Composable
private fun MessageCanvas(
    value: String,
    onValueChange: (String) -> Unit,
    enabled: Boolean,
    onFocused: () -> Unit,
    placeholder: String,
    originalIncluded: Boolean,
    originalMessageCount: Int,
    originalAttachmentCount: Int,
    includeOriginalAttachments: Boolean,
    onIncludeOriginalAttachments: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp
    ) {
        Column(Modifier.fillMaxSize()) {
            BorderlessTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 88.dp)
                    .padding(horizontal = 8.dp)
                    .onFocusChanged { if (it.isFocused) onFocused() },
                placeholder = placeholder,
                enabled = enabled,
                textStyle = MaterialTheme.typography.bodyLarge
            )
            if (originalIncluded) {
                Column(Modifier.padding(horizontal = 20.dp, vertical = 4.dp)) {
                    Text(
                        if (originalMessageCount == 1) "Original message included"
                        else "$originalMessageCount original messages included",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (originalAttachmentCount > 0) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(enabled = enabled) {
                                    onIncludeOriginalAttachments(!includeOriginalAttachments)
                                },
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Checkbox(
                                checked = includeOriginalAttachments,
                                onCheckedChange = onIncludeOriginalAttachments,
                                enabled = enabled
                            )
                            Text(
                                if (originalAttachmentCount == 1) "Include original attachment"
                                else "Include $originalAttachmentCount original attachments",
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ComposeStatusArea(
    attachmentMessage: String?,
    errorMessage: String?,
    loading: Boolean,
    loadingLabel: String
) {
    if (attachmentMessage == null && errorMessage == null && !loading) return
    RuleDivider()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (attachmentMessage != null || errorMessage != null) {
                    MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.55f)
                } else MaterialTheme.colorScheme.surface
            )
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        attachmentMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
        errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
        }
        if (loading) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                Spacer(Modifier.width(8.dp))
                Text(loadingLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
