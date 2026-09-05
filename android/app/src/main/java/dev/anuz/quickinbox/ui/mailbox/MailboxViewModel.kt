package dev.anuz.quickinbox.ui.mailbox

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import dev.anuz.quickinbox.data.MailboxCache
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.data.ThreadCache
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailboxFilters
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.ThreadDetail
import dev.anuz.quickinbox.domain.ThreadSummary
import dev.anuz.quickinbox.domain.applying
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import java.util.Date

data class MailboxUiState(
    val mailbox: MailboxKind = MailboxKind.Inbox,
    val searchText: String = "",
    val unreadOnly: Boolean = false,
    val starredOnly: Boolean = false,
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
    private val cache: MailboxCache,
    private val threadCache: ThreadCache,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) : ViewModel() {
    private val _state = MutableStateFlow(MailboxUiState())
    val state = _state.asStateFlow()

    private var generation = 0
    private var mutationRevision = 0
    private var reloadInProgress = false
    private var searchJob: Job? = null
    private var prefetchJob: Job? = null
    private var bootstrapped = false
    private val _undoOffer = MutableStateFlow<MailboxUndoOffer?>(null)
    val undoOffer = _undoOffer.asStateFlow()
    private var nextUndoId = 0L
    private val undoDecisions = mutableMapOf<Long, UndoDecision>()

    fun resolveUndo(id: Long, undo: Boolean) {
        undoDecisions[id]?.finish(undo)
        if (_undoOffer.value?.id == id) _undoOffer.value = null
    }

    private val pendingMutations = mutableListOf<OptimisticMailboxMutation>()

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
        prefetchJob?.cancel()
        _state.value = MailboxUiState(mailbox = kind, isInitialLoading = true)
        viewModelScope.launch { reload(showInitialLoading = true) }
    }

    fun onSearchChange(value: String) {
        generation += 1
        _state.update { it.copy(searchText = value, isAppending = false) }
        searchJob?.cancel()
        prefetchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(350)
            reload(showInitialLoading = true)
        }
    }

    fun toggleUnreadOnly() = updateFilters(unreadOnly = !_state.value.unreadOnly)

    fun toggleStarredOnly() = updateFilters(starredOnly = !_state.value.starredOnly)

    private fun updateFilters(
        unreadOnly: Boolean = _state.value.unreadOnly,
        starredOnly: Boolean = _state.value.starredOnly
    ) {
        generation += 1
        searchJob?.cancel()
        prefetchJob?.cancel()
        _state.update {
            it.copy(
                unreadOnly = unreadOnly,
                starredOnly = starredOnly,
                threads = emptyList(),
                total = 0,
                currentPage = 0,
                pageCount = 1,
                isInitialLoading = true,
                isAppending = false,
                isShowingCachedData = false,
                cachedAt = null
            )
        }
        viewModelScope.launch { reload(showInitialLoading = true) }
    }

    suspend fun reload(showInitialLoading: Boolean = true) {
        generation += 1
        val current = generation
        val revision = mutationRevision
        reloadInProgress = true
        _state.update {
            it.copy(
                isInitialLoading = showInitialLoading && it.threads.isEmpty(),
                initialError = null,
                refreshError = null,
                isAppending = false
            )
        }
        val snapshot = _state.value
        try {
            val page = withContext(ioDispatcher) {
                api.listThreads(
                    mailbox = snapshot.mailbox,
                    page = 1,
                    filters = MailboxFilters(query = snapshot.searchText, unreadOnly = snapshot.unreadOnly, starredOnly = snapshot.starredOnly)
                )
            }
            if (current != generation) return
            if (revision != mutationRevision) {
                reload(showInitialLoading = false)
                return
            }
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
            reapplyPendingMutations()
            saveInboxCacheIfNeeded()
            prefetchThreadDetails(_state.value.threads)
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            if (current != generation) return
            _state.update {
                if (it.threads.isEmpty()) it.copy(initialError = error.message, isInitialLoading = false)
                else it.copy(refreshError = error.message, isInitialLoading = false)
            }
        } finally {
            if (current == generation) {
                reloadInProgress = false
                _state.update { it.copy(isInitialLoading = false) }
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
        if (reloadInProgress || !snapshot.hasNextPage || snapshot.isAppending || snapshot.isInitialLoading || searchJob?.isActive == true) return
        viewModelScope.launch {
            _state.update { it.copy(isAppending = true) }
            val current = generation
            val revision = mutationRevision
            try {
                val page = withContext(ioDispatcher) {
                    api.listThreads(
                        mailbox = snapshot.mailbox,
                        page = snapshot.currentPage + 1,
                        filters = MailboxFilters(query = snapshot.searchText, unreadOnly = snapshot.unreadOnly, starredOnly = snapshot.starredOnly)
                    )
                }
                if (current != generation) return@launch
                if (revision != mutationRevision) {
                    reload(showInitialLoading = false)
                    return@launch
                }
                _state.update {
                    it.copy(
                        threads = it.threads.merging(page.threads),
                        total = page.total,
                        currentPage = page.page,
                        pageCount = maxOf(page.pageCount, 1)
                    )
                }
                reapplyPendingMutations()
                saveInboxCacheIfNeeded()
                prefetchThreadDetails(_state.value.threads)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                if (current != generation) return@launch
                _state.update { it.copy(actionError = error.message) }
            } finally {
                if (current == generation) _state.update { it.copy(isAppending = false) }
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
        if (pendingMutations.any { pending -> pending.ids.any { it in ids } }) return
        val pending = OptimisticMailboxMutation(action, _state.value, ids)
        pendingMutations += pending
        mutationRevision += 1
        prefetchJob?.cancel()
        _state.update { it.copy(mutatingIds = it.mutatingIds + ids, actionError = null) }
        unique.forEach { apply(action, it) }
        val offer = if (action.supportsUndo()) {
            _undoOffer.value?.let { resolveUndo(it.id, false) }
            MailboxUndoOffer(++nextUndoId, action, unique.size).also {
                undoDecisions[it.id] = UndoDecision()
                _undoOffer.value = it
            }
        } else null
        viewModelScope.launch {
            try {
                if (offer != null && undoDecisions.getValue(offer.id).isUndone()) {
                    pendingMutations.remove(pending)
                    mutationRevision += 1
                    _state.update { pending.rollback(it) }
                    saveInboxCacheIfNeeded()
                    return@launch
                }
                val response = withContext(ioDispatcher) {
                    api.perform(action, unique.map { it.latestId })
                }
                if (!response.ok) throw IllegalStateException("The server could not update this conversation.")
                pendingMutations.remove(pending)
                mutationRevision += 1
                // The list already reflects this action. Cache failures must not undo a server success.
                try {
                    updateThreadCache(action, unique)
                    saveInboxCacheIfNeeded()
                } catch (error: CancellationException) {
                    throw error
                } catch (_: Exception) { /* Cache will be refreshed by the next load. */ }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                pendingMutations.remove(pending)
                mutationRevision += 1
                _state.update { pending.rollback(it).copy(actionError = error.message) }
            } finally {
                offer?.let { undoDecisions.remove(it.id) }
                pendingMutations.remove(pending)
                _state.update { it.copy(mutatingIds = it.mutatingIds - ids) }
            }
        }
    }

    fun onThreadLoaded(thread: ThreadSummary, detail: ThreadDetail) {
        if (pendingMutations.any { thread.id in it.ids }) return
        mutationRevision += 1
        _state.update { state ->
            val current = state.threads.firstOrNull { it.id == thread.id } ?: return@update state
            if (detail.messages.isEmpty()) return@update state
            val updated = current.copy(
                isRead = detail.messages.all { it.isRead },
                isStarred = detail.messages.any { it.isStarred },
                isArchived = detail.messages.all { it.archivedAt != null }
            )
            when {
                state.unreadOnly && updated.isRead -> state.without(current)
                (state.starredOnly || state.mailbox == MailboxKind.Starred) && !updated.isStarred -> state.without(current)
                state.mailbox == MailboxKind.Inbox && updated.isArchived -> state.without(current)
                state.mailbox == MailboxKind.Archive && !updated.isArchived -> state.without(current)
                else -> state.replacing(updated)
            }
        }
        viewModelScope.launch { saveInboxCacheIfNeeded() }
    }

    fun onThreadMutation(action: MailAction, thread: ThreadSummary) {
        mutationRevision += 1
        prefetchJob?.cancel()
        apply(action, thread)
        viewModelScope.launch { saveInboxCacheIfNeeded() }
    }

    fun dismissErrors() {
        _state.update { it.copy(actionError = null, refreshError = null) }
    }

    private suspend fun restoreCachedInbox() {
        val snapshot = _state.value
        val current = generation
        if (snapshot.mailbox != MailboxKind.Inbox || snapshot.searchText.isNotEmpty() || snapshot.unreadOnly || snapshot.starredOnly) return
        val origin = api.credential?.origin ?: return
        val cached = withContext(ioDispatcher) { cache.load(origin, userId) } ?: return
        if (cached.threads.isEmpty() || current != generation) return
        _state.update {
            it.copy(
                threads = cached.threads.deduplicated(),
                total = cached.total,
                currentPage = cached.currentPage,
                pageCount = cached.pageCount,
                cachedAt = cached.updatedAt,
                isShowingCachedData = true
            )
        }
    }

    private suspend fun saveInboxCacheIfNeeded() {
        if (pendingMutations.isNotEmpty()) return
        val snapshot = _state.value
        val origin = api.credential?.origin ?: return
        if (snapshot.mailbox != MailboxKind.Inbox ||
            snapshot.searchText.isNotEmpty() ||
            snapshot.unreadOnly ||
            snapshot.starredOnly ||
            snapshot.currentPage < 1
        ) return
        try {
            withContext(ioDispatcher) {
                cache.save(
                    snapshot.threads,
                    snapshot.total,
                    snapshot.pageCount,
                    origin,
                    userId,
                    snapshot.currentPage
                )
            }
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // The cache is an optional offline fallback; a storage failure must not fail a live request.
        }
    }

    private suspend fun updateThreadCache(action: MailAction, threads: List<ThreadSummary>) {
        val origin = api.credential?.origin ?: return
        withContext(ioDispatcher) {
            threads.forEach { thread ->
                runCatching {
                    if (action == MailAction.Delete) {
                        threadCache.remove(origin, userId, thread.threadId)
                    } else {
                        threadCache.load(origin, userId, thread.threadId)?.let { cached ->
                            threadCache.save(cached.detail.applying(action), origin, userId, thread.threadId)
                        }
                    }
                }
            }
        }
    }

    private fun prefetchThreadDetails(threads: List<ThreadSummary>) {
        val origin = api.credential?.origin ?: return
        val candidates = threads.distinctBy { it.threadId }.filter { it.threadId.isNotBlank() }
        if (candidates.isEmpty()) return

        prefetchJob?.cancel()
        prefetchJob = viewModelScope.launch(ioDispatcher) {
            delay(PREFETCH_DELAY_MILLIS)
            val permits = Semaphore(PREFETCH_CONCURRENCY)
            coroutineScope {
                candidates.map { thread ->
                    async {
                        permits.withPermit {
                            try {
                                currentCoroutineContext().ensureActive()
                                if (threadCache.load(origin, userId, thread.threadId) == null) {
                                    val detail = api.thread(thread.threadId)
                                    currentCoroutineContext().ensureActive()
                                    threadCache.save(detail, origin, userId, thread.threadId)
                                }
                            } catch (error: CancellationException) {
                                throw error
                            } catch (_: Exception) {
                                // Prefetch is best effort and must never disrupt mailbox loading.
                            }
                        }
                    }
                }.awaitAll()
            }
        }
    }

    private fun reapplyPendingMutations() {
        pendingMutations.filter { it.before.sameMailboxView(_state.value) }.forEach { pending ->
            _state.update { it.copy(mutatingIds = it.mutatingIds + pending.ids) }
            pending.before.threads.filter { it.id in pending.ids }.forEach { apply(pending.action, it) }
        }
    }

    private fun apply(action: MailAction, thread: ThreadSummary) {
        _state.update { it.applyingMailboxAction(action, thread) }
    }

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
    private val cache: MailboxCache,
    private val threadCache: ThreadCache
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        MailboxViewModel(api, userId, cache, threadCache) as T
}

private const val PREFETCH_CONCURRENCY = 3
private const val PREFETCH_DELAY_MILLIS = 500L
