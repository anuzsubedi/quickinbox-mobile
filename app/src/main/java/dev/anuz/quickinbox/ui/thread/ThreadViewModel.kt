package dev.anuz.quickinbox.ui.thread

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.domain.DownloadedAttachment
import dev.anuz.quickinbox.domain.EmailAttachment
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.ThreadDetail
import dev.anuz.quickinbox.domain.ThreadMessage
import dev.anuz.quickinbox.domain.ThreadSummary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

data class ThreadUiState(
    val detail: ThreadDetail? = null,
    val isLoading: Boolean = false,
    val actionInProgress: MailAction? = null,
    val errorMessage: String? = null,
    val isRead: Boolean = true,
    val isStarred: Boolean = false,
    val isArchived: Boolean = false,
    val isTrashed: Boolean = false,
    val downloadingIds: Set<String> = emptySet(),
    val openedAttachment: DownloadedAttachment? = null
) {
    val chronologicalMessages: List<ThreadMessage>
        get() = (detail?.messages ?: emptyList()).sortedWith(
            compareBy<ThreadMessage> { it.createdAt }.thenBy { it.id }
        )

    val actionTargetId: String
        get() = chronologicalMessages.lastOrNull()?.id ?: ""
}

class ThreadViewModel(
    private val api: QuickInboxApi,
    private val threadId: String,
    summary: ThreadSummary?,
    private val cacheDirectory: File
) : ViewModel() {
    private val _state = MutableStateFlow(
        ThreadUiState(
            isRead = summary?.isRead ?: true,
            isStarred = summary?.isStarred ?: false,
            isArchived = summary?.isArchived ?: false
        )
    )
    val state = _state.asStateFlow()

    fun load() {
        if (_state.value.isLoading) return
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val value = withContext(Dispatchers.IO) { api.thread(threadId) }
                _state.update {
                    it.copy(
                        detail = value,
                        isLoading = false,
                        isRead = value.messages.isEmpty() || value.messages.all { message -> message.isRead },
                        isStarred = value.messages.any { message -> message.isStarred },
                        isArchived = value.messages.isNotEmpty() && value.messages.all { message -> message.archivedAt != null },
                        isTrashed = value.messages.isNotEmpty() && value.messages.all { message -> message.deletedAt != null }
                    )
                }
            } catch (error: kotlinx.coroutines.CancellationException) {
                throw error
            } catch (error: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = error.message) }
            }
        }
    }

    fun perform(action: MailAction, onMailboxMutation: () -> Unit, onExit: (() -> Unit)? = null) {
        if (_state.value.actionInProgress != null) return
        viewModelScope.launch {
            _state.update { it.copy(actionInProgress = action, errorMessage = null) }
            try {
                val target = _state.value.actionTargetId.ifEmpty { threadId }
                withContext(Dispatchers.IO) {
                    if (action == MailAction.Delete) api.deletePermanently(target)
                    else api.perform(action, listOf(target))
                }
                apply(action)
                onMailboxMutation()
                if (action == MailAction.Trash || action == MailAction.Delete || action == MailAction.Archive) {
                    onExit?.invoke()
                }
            } catch (error: Exception) {
                _state.update { it.copy(errorMessage = error.message) }
            } finally {
                _state.update { it.copy(actionInProgress = null) }
            }
        }
    }

    fun download(message: ThreadMessage, attachment: EmailAttachment) {
        if (attachment.id in _state.value.downloadingIds) return
        viewModelScope.launch {
            _state.update { it.copy(downloadingIds = it.downloadingIds + attachment.id, errorMessage = null) }
            try {
                val downloaded = withContext(Dispatchers.IO) {
                    api.downloadAttachment(message.id, attachment, File(cacheDirectory, "attachments"))
                }
                _state.update { it.copy(openedAttachment = downloaded) }
            } catch (error: Exception) {
                _state.update { it.copy(errorMessage = error.message) }
            } finally {
                _state.update { it.copy(downloadingIds = it.downloadingIds - attachment.id) }
            }
        }
    }

    fun consumeOpenedAttachment() {
        _state.update { it.copy(openedAttachment = null) }
    }

    private fun apply(action: MailAction) {
        _state.update {
            when (action) {
                MailAction.Read -> it.copy(isRead = true)
                MailAction.Unread -> it.copy(isRead = false)
                MailAction.Star -> it.copy(isStarred = true)
                MailAction.Unstar -> it.copy(isStarred = false)
                MailAction.Archive -> it.copy(isArchived = true)
                MailAction.Unarchive -> it.copy(isArchived = false)
                MailAction.Trash -> it.copy(isTrashed = true)
                MailAction.Restore -> it.copy(isTrashed = false)
                else -> it
            }
        }
    }
}

class ThreadViewModelFactory(
    private val api: QuickInboxApi,
    private val threadId: String,
    private val summary: ThreadSummary?,
    private val cacheDirectory: File
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        ThreadViewModel(api, threadId, summary, cacheDirectory) as T
}
