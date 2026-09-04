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
import dev.anuz.quickinbox.domain.applying
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Job
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
    private val cache: ThreadCache,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) : ViewModel() {
    private val _state = MutableStateFlow(
        ThreadUiState(
            isRead = summary?.isRead ?: true,
            isStarred = summary?.isStarred ?: false,
            isArchived = summary?.isArchived ?: false
        )
    )
    val state = _state.asStateFlow()

    private var loadJob: Job? = null

    fun load(onLoaded: (ThreadDetail) -> Unit = {}) {
        if (loadJob?.isActive == true || _state.value.actionInProgress != null) return
        loadJob = viewModelScope.launch {
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
                    val cached = withContext(ioDispatcher) {
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
                val value = withContext(ioDispatcher) { api.thread(threadId) }
                // Persist the read action before publishing the opened conversation to the mailbox.
                val opened = if (value.messages.any { !it.isRead }) {
                    try {
                        val response = withContext(ioDispatcher) {
                            api.perform(MailAction.Read, listOf(value.messages.maxBy { it.createdAt ?: Date(0) }.id))
                        }
                        if (!response.ok) throw IllegalStateException("The server could not mark this conversation as read.")
                        value.applying(MailAction.Read)
                    } catch (error: CancellationException) {
                        throw error
                    } catch (error: Exception) {
                        _state.update { it.copy(errorMessage = error.message) }
                        value
                    }
                } else value
                _state.update {
                    it.withDetail(opened).copy(
                        isLoading = false,
                        isRefreshing = false,
                        isShowingSavedData = false,
                        savedDataMessage = null
                    )
                }
                onLoaded(opened)
                if (origin != null) {
                    withContext(ioDispatcher) {
                        runCatching { cache.save(opened, origin, userId, threadId) }
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
        val pendingLoad = loadJob
        _state.update { it.copy(actionInProgress = action, errorMessage = null) }
        viewModelScope.launch {
            try {
                // Finish any reader load before applying the user's newer action.
                pendingLoad?.join()
                val target = _state.value.actionTargetId.ifEmpty { threadId }
                withContext(ioDispatcher) {
                    val ok = if (action == MailAction.Delete) api.deletePermanently(target).ok
                    else api.perform(action, listOf(target)).ok
                    if (!ok) throw IllegalStateException("The server could not update this conversation.")
                }
                apply(action)
                onMailboxMutation()
                persistMutation(action)
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
                val downloaded = withContext(ioDispatcher) {
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
        withContext(ioDispatcher) {
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
