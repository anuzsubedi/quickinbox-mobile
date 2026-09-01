package dev.anuz.quickinbox.ui.compose

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Base64
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import dev.anuz.quickinbox.data.AppPreferences
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.domain.ComposeMessage
import dev.anuz.quickinbox.domain.MailAddress
import dev.anuz.quickinbox.domain.ForwardMessage
import dev.anuz.quickinbox.domain.OutboundAttachment
import dev.anuz.quickinbox.domain.ReplyMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

sealed class ComposeMode {
    data object NewMessage : ComposeMode()
    data class Draft(val id: String) : ComposeMode()
    data class Reply(
        val messageId: String,
        val recipient: String,
        val subject: String,
        val recipientName: String? = null,
        val fromAddressHint: String? = null,
        val originalTo: String = "",
        val originalCc: String? = null
    ) : ComposeMode()
    sealed class Forward : ComposeMode() {
        abstract val subject: String
        abstract val messageCount: Int
        abstract val attachmentCount: Int
        abstract val fromAddressHint: String?

        data class Message(
            val messageId: String,
            override val subject: String,
            override val attachmentCount: Int = 0,
            override val fromAddressHint: String? = null
        ) : Forward() {
            override val messageCount: Int = 1
        }

        data class Thread(
            val threadId: String,
            override val subject: String,
            override val messageCount: Int,
            override val attachmentCount: Int = 0,
            override val fromAddressHint: String? = null
        ) : Forward()
    }

    val title: String
        get() = when (this) {
            NewMessage -> "New message"
            is Draft -> "Draft"
            is Reply -> "Reply"
            is Forward.Message -> "Forward"
            is Forward.Thread -> "Forward all"
        }

    val draftId: String? get() = (this as? Draft)?.id
}

data class ComposeAttachment(
    val id: String = UUID.randomUUID().toString(),
    val filename: String,
    val contentType: String,
    val byteCount: Int,
    val encodedContent: String
) {
    val outbound get() = OutboundAttachment(filename, contentType, encodedContent)
}

data class ComposeUiState(
    val to: List<String> = emptyList(),
    val cc: List<String> = emptyList(),
    val bcc: List<String> = emptyList(),
    val subject: String = "",
    val body: String = "",
    val addresses: List<MailAddress> = emptyList(),
    val selectedFromAddressId: String? = null,
    val attachments: List<ComposeAttachment> = emptyList(),
    val includeOriginalAttachments: Boolean = true,
    val isLoadingAddresses: Boolean = false,
    val isLoadingDraft: Boolean = false,
    val isImporting: Boolean = false,
    val isSending: Boolean = false,
    val errorMessage: String? = null,
    val attachmentMessage: String? = null
)

class ComposeViewModel(
    private val api: QuickInboxApi,
    val mode: ComposeMode,
    private val preferences: AppPreferences
) : ViewModel() {
    private val _state = MutableStateFlow(
        when (mode) {
            ComposeMode.NewMessage -> ComposeUiState()
            is ComposeMode.Draft -> ComposeUiState()
            is ComposeMode.Reply -> ComposeUiState(to = listOf(mode.recipient), subject = mode.subject)
            is ComposeMode.Forward -> ComposeUiState(subject = mode.subject)
        }
    )
    val state = _state.asStateFlow()

    private var didLoadAddresses = false
    private var didLoadDraft = false

    val isReply: Boolean get() = mode is ComposeMode.Reply

    fun onTo(value: List<String>) = _state.update { it.copy(to = value, errorMessage = null) }
    fun onCc(value: List<String>) = _state.update { it.copy(cc = value, errorMessage = null) }
    fun onBcc(value: List<String>) = _state.update { it.copy(bcc = value, errorMessage = null) }
    fun onSubject(value: String) = _state.update { it.copy(subject = value, errorMessage = null) }
    fun onBody(value: String) = _state.update { it.copy(body = value, errorMessage = null) }
    fun onFrom(id: String) = _state.update { it.copy(selectedFromAddressId = id) }
    fun onIncludeOriginalAttachments(include: Boolean) =
        _state.update { it.copy(includeOriginalAttachments = include, errorMessage = null) }

    fun load() {
        viewModelScope.launch {
            loadAddressesIfNeeded()
            loadDraftIfNeeded()
        }
    }

    fun importUris(context: Context, uris: List<Uri>) {
        if (uris.isEmpty()) return
        viewModelScope.launch {
            _state.update { it.copy(isImporting = true, attachmentMessage = null) }
            val imported = _state.value.attachments.toMutableList()
            val messages = mutableListOf<String>()
            try {
                for (uri in uris) {
                    if (imported.size >= MAX_COUNT) {
                        messages += "You can attach up to $MAX_COUNT files."
                        break
                    }
                    try {
                        val attachment = withContext(Dispatchers.IO) { readAttachment(context, uri) }
                        if (imported.sumOf { it.byteCount } + attachment.byteCount > MAX_TOTAL_BYTES) {
                            messages += "Attachments cannot exceed 25 MB in total."
                            continue
                        }
                        imported += attachment
                    } catch (error: CancellationException) {
                        throw error
                    } catch (error: Exception) {
                        messages += error.message ?: "A file could not be attached."
                    }
                }
                _state.update {
                    it.copy(
                        attachments = imported,
                        attachmentMessage = messages.takeIf { list -> list.isNotEmpty() }?.joinToString("\n")
                    )
                }
            } finally {
                _state.update { it.copy(isImporting = false) }
            }
        }
    }

    fun removeAttachment(id: String) {
        if (_state.value.isSending) return
        _state.update { it.copy(attachments = it.attachments.filterNot { attachment -> attachment.id == id }, attachmentMessage = null) }
    }

    fun send(onSent: () -> Unit) {
        val snapshot = _state.value
        if (snapshot.isSending) return
        val validation = validationMessage(snapshot)
        if (validation != null) {
            _state.update { it.copy(errorMessage = validation) }
            return
        }
        viewModelScope.launch {
            _state.update { it.copy(isSending = true, errorMessage = null) }
            try {
                val outbound = snapshot.attachments.takeIf { it.isNotEmpty() }?.map { it.outbound }
                withContext(Dispatchers.IO) {
                    when (val current = mode) {
                        ComposeMode.NewMessage, is ComposeMode.Draft -> api.send(
                            ComposeMessage(
                                draftId = current.draftId,
                                fromAddressId = snapshot.selectedFromAddressId,
                                to = snapshot.to.joinToString(", "),
                                cc = snapshot.cc.joinToString(", ").ifEmpty { null },
                                bcc = snapshot.bcc.joinToString(", ").ifEmpty { null },
                                subject = snapshot.subject.trim(),
                                text = snapshot.body.trim(),
                                attachments = outbound
                            )
                        )
                        is ComposeMode.Reply -> api.reply(
                            current.messageId,
                            ReplyMessage(
                                fromAddressId = snapshot.selectedFromAddressId,
                                to = snapshot.to.joinToString(", ").ifEmpty { null },
                                cc = snapshot.cc.joinToString(", ").ifEmpty { null },
                                bcc = snapshot.bcc.joinToString(", ").ifEmpty { null },
                                text = snapshot.body.trim(),
                                attachments = outbound
                            )
                        )
                        is ComposeMode.Forward -> {
                            val request = ForwardMessage(
                                fromAddressId = snapshot.selectedFromAddressId,
                                to = snapshot.to.joinToString(", "),
                                cc = snapshot.cc.joinToString(", ").ifEmpty { null },
                                bcc = snapshot.bcc.joinToString(", ").ifEmpty { null },
                                text = snapshot.body.trim().ifEmpty { null },
                                includeAttachments = snapshot.includeOriginalAttachments
                            )
                            when (current) {
                                is ComposeMode.Forward.Message -> api.forwardMessage(current.messageId, request)
                                is ComposeMode.Forward.Thread -> api.forwardThread(current.threadId, request)
                            }
                        }
                    }
                }
                onSent()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                _state.update { it.copy(errorMessage = error.message ?: "QuickInbox could not send this message. Try again.") }
            } finally {
                _state.update { it.copy(isSending = false) }
            }
        }
    }

    private suspend fun loadAddressesIfNeeded() {
        if (mode is ComposeMode.Forward) return
        if (didLoadAddresses) return
        didLoadAddresses = true
        _state.update { it.copy(isLoadingAddresses = true) }
        try {
            val loaded = withContext(Dispatchers.IO) { api.addresses() }
            _state.update { state ->
                val selected = if (mode is ComposeMode.Reply || mode is ComposeMode.Forward) {
                    state.selectedFromAddressId
                } else {
                    state.selectedFromAddressId ?: preferredAddress(loaded)?.id
                }
                state.copy(
                    addresses = loaded,
                    selectedFromAddressId = selected,
                    isLoadingAddresses = false,
                    errorMessage = if (loaded.isEmpty()) {
                        "No sending address is configured. Add one in QuickInbox settings first."
                    } else state.errorMessage
                )
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            _state.update { it.copy(isLoadingAddresses = false, errorMessage = error.message ?: "Sending addresses could not be loaded.") }
        } finally {
            _state.update { it.copy(isLoadingAddresses = false) }
        }
    }

    private suspend fun loadDraftIfNeeded() {
        val draftId = mode.draftId ?: return
        if (didLoadDraft) return
        didLoadDraft = true
        _state.update { it.copy(isLoadingDraft = true) }
        try {
            val draft = withContext(Dispatchers.IO) { api.draft(draftId) }
            _state.update { state ->
                state.copy(
                    to = parseRecipients(draft.to),
                    cc = parseRecipients(draft.cc.orEmpty()),
                    bcc = parseRecipients(draft.bcc.orEmpty()),
                    subject = draft.subject,
                    body = draft.text.orEmpty(),
                    selectedFromAddressId = state.addresses.firstOrNull {
                        it.address.equals(draft.fromAddress, ignoreCase = true)
                    }?.id ?: preferredAddress(state.addresses)?.id,
                    isLoadingDraft = false
                )
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            _state.update {
                it.copy(
                    isLoadingDraft = false,
                    errorMessage = error.message ?: "QuickInbox couldn’t load this draft. Try again."
                )
            }
        } finally {
            _state.update { it.copy(isLoadingDraft = false) }
        }
    }

    private fun preferredAddress(addresses: List<MailAddress>): MailAddress? {
        val saved = preferences.selectedSendingAddressId
        return addresses.firstOrNull { it.id == saved }
            ?: addresses.firstOrNull { it.isDefault }
            ?: addresses.firstOrNull()
    }

    private fun validationMessage(state: ComposeUiState): String? {
        if (mode !is ComposeMode.Forward && state.body.trim().isEmpty()) return "Write a message before sending."
        if (mode !is ComposeMode.Reply && mode !is ComposeMode.Forward && state.selectedFromAddressId == null) {
            return "Choose a sending address."
        }
        recipientError(state.to, "To", required = true)?.let { return it }
        recipientError(state.cc, "Cc", required = false)?.let { return it }
        recipientError(state.bcc, "Bcc", required = false)?.let { return it }
        if (mode is ComposeMode.Reply) return null
        val subject = state.subject.trim()
        if (subject.isEmpty()) return "Add a subject."
        if (subject.length > 200) return "The subject must be 200 characters or fewer."
        return null
    }

    private fun parseRecipients(value: String): List<String> =
        value.split(',').map { it.trim() }.filter { it.isNotEmpty() }

    private fun recipientError(recipients: List<String>, label: String, required: Boolean): String? {
        if (recipients.isEmpty()) {
            return if (required) "Add at least one recipient." else null
        }
        for (recipient in recipients) {
            if (!isValidEmail(recipient)) return "Check the email address in $label: $recipient"
        }
        return null
    }

    private fun isValidEmail(value: String): Boolean {
        if (value.any { it.isWhitespace() }) return false
        val parts = value.split('@')
        if (parts.size != 2 || parts[0].isEmpty() || parts[1].isEmpty()) return false
        return parts[1].contains('.') && !parts[1].startsWith('.') && !parts[1].endsWith('.')
    }

    private fun readAttachment(context: Context, uri: Uri): ComposeAttachment {
        val resolver = context.contentResolver
        var filename = "attachment"
        var size = 0L
        resolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (cursor.moveToFirst()) {
                if (nameIndex >= 0) filename = cursor.getString(nameIndex) ?: filename
                if (sizeIndex >= 0) size = cursor.getLong(sizeIndex)
            }
        }
        if (size > MAX_BYTES) throw IllegalArgumentException("$filename exceeds the 5 MB limit.")
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalArgumentException("$filename could not be attached.")
        if (bytes.isEmpty()) throw IllegalArgumentException("$filename is empty.")
        if (bytes.size > MAX_BYTES) throw IllegalArgumentException("$filename exceeds the 5 MB limit.")
        val type = resolver.getType(uri) ?: "application/octet-stream"
        return ComposeAttachment(
            filename = filename,
            contentType = type,
            byteCount = bytes.size,
            encodedContent = Base64.encodeToString(bytes, Base64.NO_WRAP)
        )
    }

    companion object {
        const val MAX_COUNT = 5
        const val MAX_BYTES = 5 * 1024 * 1024
        const val MAX_TOTAL_BYTES = 25 * 1024 * 1024
    }
}

class ComposeViewModelFactory(
    private val api: QuickInboxApi,
    private val mode: ComposeMode,
    private val preferences: AppPreferences
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        ComposeViewModel(api, mode, preferences) as T
}
