package dev.anuz.quickinbox.ui.mailbox

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import dev.anuz.quickinbox.data.MailboxCache
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailboxFilters
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadSummary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Date

data class MailboxUiState(
    val mailbox: MailboxKind = MailboxKind.Inbox,
    val searchText: String = "",
    val unreadOnly: Boolean = false,
    val threads: List<ThreadSummary> = emptyList(),
    val total: Int = 0,
    val currentPage: Int = 0,
    val pageCount: Int = 1,
    val isInitialLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isAppending: Boolean = false,
    val mutatingIds: Set<String> = emptySet(),
    val initialError: String? = null,
    val refreshError: String? = null,
    val actionError: String? = null,
    val cachedAt: Date? = null,
    val isShowingCachedData: Boolean = false
) {
    val hasNextPage: Boolean get() = currentPage > 0 && currentPage < pageCount
}

class MailboxViewModel(
    private val api: QuickInboxApi,
    private val userId: String,
    private val cache: MailboxCache
) : ViewModel() {
    private val _state = MutableStateFlow(MailboxUiState())
    val state = _state.asStateFlow()

    private var generation = 0
    private var searchJob: Job? = null
    private var bootstrapped = false

    fun bootstrap() {
        if (bootstrapped) return
        bootstrapped = true
        viewModelScope.launch {
            restoreCachedInbox()
            reload(showInitialLoading = _state.value.threads.isEmpty())
        }
    }

    fun selectMailbox(kind: MailboxKind) {
        if (kind == _state.value.mailbox) return
        generation += 1
        searchJob?.cancel()
        _state.value = MailboxUiState(mailbox = kind, isInitialLoading = true)
        viewModelScope.launch { reload(showInitialLoading = true) }
    }

    fun onSearchChange(value: String) {
        _state.update { it.copy(searchText = value) }
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(350)
            reload(showInitialLoading = true)
        }
    }

    fun toggleUnreadOnly() {
        _state.update { it.copy(unreadOnly = !it.unreadOnly) }
        viewModelScope.launch { reload(showInitialLoading = true) }
    }

    suspend fun reload(showInitialLoading: Boolean = true) {
        generation += 1
        val current = generation
        _state.update {
            it.copy(
                isInitialLoading = showInitialLoading && it.threads.isEmpty(),
                initialError = null,
                refreshError = null
            )
        }
        val snapshot = _state.value
        try {
            val page = withContext(Dispatchers.IO) {
                api.listThreads(
                    mailbox = snapshot.mailbox,
                    page = 1,
                    filters = MailboxFilters(query = snapshot.searchText, unreadOnly = snapshot.unreadOnly)
                )
            }
            if (current != generation) return
            _state.update {
                it.copy(
                    threads = page.threads.deduplicated(),
                    total = page.total,
                    currentPage = page.page,
                    pageCount = maxOf(page.pageCount, 1),
                    isShowingCachedData = false,
                    cachedAt = null,
                    isInitialLoading = false
                )
            }
            saveInboxCacheIfNeeded()
        } catch (error: kotlinx.coroutines.CancellationException) {
            throw error
        } catch (error: Exception) {
            if (current != generation) return
            _state.update {
                if (it.threads.isEmpty()) it.copy(initialError = error.message, isInitialLoading = false)
                else it.copy(refreshError = error.message, isInitialLoading = false)
            }
        }
    }

    fun refresh() {
        if (_state.value.isRefreshing) return
        viewModelScope.launch {
            _state.update { it.copy(isRefreshing = true) }
            try {
                reload(showInitialLoading = false)
            } finally {
                _state.update { it.copy(isRefreshing = false) }
            }
        }
    }

    fun loadNextPage() {
        val snapshot = _state.value
        if (!snapshot.hasNextPage || snapshot.isAppending || snapshot.isInitialLoading) return
        viewModelScope.launch {
            _state.update { it.copy(isAppending = true) }
            val current = generation
            try {
                val page = withContext(Dispatchers.IO) {
                    api.listThreads(
                        mailbox = snapshot.mailbox,
                        page = snapshot.currentPage + 1,
                        filters = MailboxFilters(query = snapshot.searchText, unreadOnly = snapshot.unreadOnly)
                    )
                }
                if (current != generation) return@launch
                _state.update {
                    it.copy(
                        threads = it.threads.merging(page.threads),
                        total = page.total,
                        currentPage = page.page,
                        pageCount = maxOf(page.pageCount, 1)
                    )
                }
            } catch (error: Exception) {
                if (current != generation) return@launch
                _state.update { it.copy(actionError = error.message) }
            } finally {
                _state.update { it.copy(isAppending = false) }
            }
        }
    }

    fun perform(action: MailAction, thread: ThreadSummary) {
        perform(action, listOf(thread))
    }

    fun perform(action: MailAction, threads: List<ThreadSummary>) {
        val unique = threads.distinctBy { it.id }
        if (unique.isEmpty()) return
        val ids = unique.map { it.id }.toSet()
        if (_state.value.mutatingIds.any { it in ids }) return
        viewModelScope.launch {
            _state.update { it.copy(mutatingIds = it.mutatingIds + ids) }
            try {
                val response = withContext(Dispatchers.IO) {
                    api.perform(action, unique.map { it.latestId })
                }
                if (!response.ok) throw IllegalStateException("The server could not update this conversation.")
                unique.forEach { apply(action, it) }
                saveInboxCacheIfNeeded()
            } catch (error: Exception) {
                _state.update { it.copy(actionError = error.message) }
            } finally {
                _state.update { it.copy(mutatingIds = it.mutatingIds - ids) }
            }
        }
    }

    fun dismissErrors() {
        _state.update { it.copy(actionError = null, refreshError = null) }
    }

    private suspend fun restoreCachedInbox() {
        val snapshot = _state.value
        if (snapshot.mailbox != MailboxKind.Inbox || snapshot.searchText.isNotEmpty() || snapshot.unreadOnly) return
        val origin = api.credential?.origin ?: return
        val cached = withContext(Dispatchers.IO) { cache.load(origin, userId) } ?: return
        if (cached.threads.isEmpty()) return
        _state.update {
            it.copy(
                threads = cached.threads.deduplicated(),
                total = cached.total,
                currentPage = 1,
                pageCount = cached.pageCount,
                cachedAt = cached.updatedAt,
                isShowingCachedData = true
            )
        }
    }

    private suspend fun saveInboxCacheIfNeeded() {
        val snapshot = _state.value
        val origin = api.credential?.origin ?: return
        if (snapshot.mailbox != MailboxKind.Inbox ||
            snapshot.searchText.isNotEmpty() ||
            snapshot.unreadOnly ||
            snapshot.currentPage < 1
        ) return
        withContext(Dispatchers.IO) {
            cache.save(snapshot.threads, snapshot.total, snapshot.pageCount, origin, userId)
        }
    }

    private fun apply(action: MailAction, thread: ThreadSummary) {
        _state.update { state ->
            val updated = when (action) {
                MailAction.Read ->
                    if (state.unreadOnly) state.without(thread)
                    else state.replacing(thread.copy(isRead = true))
                MailAction.Unread -> state.replacing(thread.copy(isRead = false))
                MailAction.Star -> state.replacing(thread.copy(isStarred = true))
                MailAction.Unstar ->
                    if (state.mailbox == MailboxKind.Starred) state.without(thread)
                    else state.replacing(thread.copy(isStarred = false))
                MailAction.Archive ->
                    if (state.mailbox == MailboxKind.Inbox) state.without(thread)
                    else state.replacing(thread.copy(isArchived = true))
                MailAction.Unarchive ->
                    if (state.mailbox == MailboxKind.Archive) state.without(thread)
                    else state.replacing(thread.copy(isArchived = false))
                MailAction.Trash, MailAction.Restore, MailAction.Delete -> state.without(thread)
                MailAction.ReadAll, MailAction.EmptyTrash -> state
            }
            updated
        }
    }

    private fun MailboxUiState.replacing(thread: ThreadSummary) = copy(
        threads = threads.map { if (it.id == thread.id) thread else it }
    )

    private fun MailboxUiState.without(thread: ThreadSummary) = copy(
        threads = threads.filterNot { it.id == thread.id },
        total = maxOf(0, total - 1)
    )
}

private fun List<ThreadSummary>.deduplicated() = emptyList<ThreadSummary>().merging(this)

private fun List<ThreadSummary>.merging(incoming: List<ThreadSummary>): List<ThreadSummary> {
    val result = toMutableList()
    val indices = result.withIndex().associate { it.value.id to it.index }.toMutableMap()
    for (thread in incoming) {
        val index = indices[thread.id]
        if (index != null) result[index] = thread
        else {
            indices[thread.id] = result.size
            result += thread
        }
    }
    return result
}

class MailboxViewModelFactory(
    private val api: QuickInboxApi,
    private val userId: String,
    private val cache: MailboxCache
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        MailboxViewModel(api, userId, cache) as T
}
