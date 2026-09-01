package dev.anuz.quickinbox.ui.thread

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.data.ThreadCache
import dev.anuz.quickinbox.domain.DownloadedAttachment
import dev.anuz.quickinbox.domain.EmailAttachment
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.ThreadDetail
import dev.anuz.quickinbox.domain.ThreadMessage
import dev.anuz.quickinbox.domain.ThreadSummary
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Date

data class ThreadUiState(
    val detail: ThreadDetail? = null,
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isShowingSavedData: Boolean = false,
    val savedDataMessage: String? = null,
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
    private val cacheDirectory: File,
    private val userId: String,
    private val cache: ThreadCache
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
        if (_state.value.isLoading || _state.value.isRefreshing) return
        viewModelScope.launch {
            val origin = api.credential?.origin
            _state.update {
                it.copy(
                    isLoading = it.detail == null,
                    isRefreshing = it.detail != null,
                    errorMessage = null
                )
            }
            try {
                if (_state.value.detail == null && origin != null) {
                    val cached = withContext(Dispatchers.IO) {
                        runCatching { cache.load(origin, userId, threadId) }.getOrNull()
                    }
                    if (cached != null) {
                        _state.update {
                            it.withDetail(cached.detail, updateFlags = false).copy(
                                isLoading = false,
                                isRefreshing = true,
                                isShowingSavedData = true,
                                savedDataMessage = "Showing saved conversation · Refreshing"
                            )
                        }
                    }
                }
                val value = withContext(Dispatchers.IO) { api.thread(threadId) }
                _state.update {
                    it.withDetail(value).copy(
                        isLoading = false,
                        isRefreshing = false,
                        isShowingSavedData = false,
                        savedDataMessage = null
                    )
                }
                if (origin != null) {
                    withContext(Dispatchers.IO) {
                        runCatching { cache.save(value, origin, userId, threadId) }
                    }
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                _state.update {
                    if (it.detail != null) {
                        it.copy(
                            isLoading = false,
                            isRefreshing = false,
                            isShowingSavedData = true,
                            savedDataMessage = "Showing saved conversation · Offline",
                            errorMessage = null
                        )
                    } else {
                        it.copy(isLoading = false, isRefreshing = false, errorMessage = error.message)
                    }
                }
            } finally {
                _state.update { it.copy(isLoading = false, isRefreshing = false) }
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
                persistMutation(action)
                onMailboxMutation()
                if (action == MailAction.Trash || action == MailAction.Delete || action == MailAction.Archive) {
                    onExit?.invoke()
                }
            } catch (error: CancellationException) {
                throw error
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
            } catch (error: CancellationException) {
                throw error
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
            val updated = when (action) {
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
            updated.copy(detail = updated.detail?.applying(action))
        }
    }

    private suspend fun persistMutation(action: MailAction) {
        val origin = api.credential?.origin ?: return
        withContext(Dispatchers.IO) {
            if (action == MailAction.Delete) {
                runCatching { cache.remove(origin, userId, threadId) }
            } else {
                _state.value.detail?.let { detail ->
                    runCatching { cache.save(detail, origin, userId, threadId) }
                }
            }
        }
    }

    private fun ThreadUiState.withDetail(value: ThreadDetail, updateFlags: Boolean = true): ThreadUiState =
        if (updateFlags) {
            copy(
                detail = value,
                isRead = value.messages.isEmpty() || value.messages.all { it.isRead },
                isStarred = value.messages.any { it.isStarred },
                isArchived = value.messages.isNotEmpty() && value.messages.all { it.archivedAt != null },
                isTrashed = value.messages.isNotEmpty() && value.messages.all { it.deletedAt != null }
            )
        } else {
            copy(detail = value)
        }

    private fun ThreadDetail.applying(action: MailAction): ThreadDetail {
        val now = Date()
        return copy(
            messages = messages.map { message ->
                when (action) {
                    MailAction.Read -> message.copy(isRead = true)
                    MailAction.Unread -> message.copy(isRead = false)
                    MailAction.Star -> message.copy(isStarred = true)
                    MailAction.Unstar -> message.copy(isStarred = false)
                    MailAction.Archive -> message.copy(archivedAt = message.archivedAt ?: now)
                    MailAction.Unarchive -> message.copy(archivedAt = null)
                    MailAction.Trash -> message.copy(deletedAt = message.deletedAt ?: now)
                    MailAction.Restore -> message.copy(deletedAt = null)
                    else -> message
                }
            }
        )
    }
}

class ThreadViewModelFactory(
    private val api: QuickInboxApi,
    private val threadId: String,
    private val summary: ThreadSummary?,
    private val cacheDirectory: File,
    private val userId: String,
    private val cache: ThreadCache
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        ThreadViewModel(api, threadId, summary, cacheDirectory, userId, cache) as T
}
