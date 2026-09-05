package dev.anuz.quickinbox

import androidx.lifecycle.ViewModelStore
import com.google.gson.GsonBuilder
import dev.anuz.quickinbox.data.*
import dev.anuz.quickinbox.domain.*
import dev.anuz.quickinbox.ui.mailbox.MailboxViewModel
import dev.anuz.quickinbox.ui.thread.ThreadViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CoroutineDispatcher
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.*
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class MailStateTest {
    @get:Rule val temporary = TemporaryFolder()
    private val dispatcher = StandardTestDispatcher()
    private val store = ViewModelStore()
    private val gson = GsonBuilder().registerTypeAdapter(Date::class.java, ApiDateAdapter()).create()
    private lateinit var server: MockWebServer
    private lateinit var api: QuickInboxApi
    private lateinit var cache: ThreadCache
    private lateinit var inboxCache: MailboxCache
    private lateinit var mailbox: MailboxViewModel
    private lateinit var origin: String
    private val summary = ThreadSummary(threadId = "thread-1", latestId = "message-1")
    private val detail = ThreadDetail(threadId = "thread-1", messages = listOf(ThreadMessage(id = "message-1")))

    @Before fun setup() {
        Dispatchers.setMain(dispatcher)
        server = MockWebServer().also { it.start() }
        origin = server.url("/").toString().trimEnd('/')
        api = QuickInboxApi(gson).also { it.install(Credential(origin, "test-token", Date(System.currentTimeMillis() + 60_000))) }
        cache = ThreadCache(temporary.newFolder("threads"), gson)
        cache.save(detail, origin, "user", summary.threadId)
        inboxCache = MailboxCache(temporary.newFolder("mailbox"), gson)
        mailbox = MailboxViewModel(api, "user", inboxCache, cache, dispatcher)
        store.put("mailbox", mailbox)
    }

    @After fun cleanup() {
        store.clear()
        Dispatchers.resetMain()
        server.shutdown()
    }

    private fun enqueue(value: Any) {
        server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setBody(gson.toJson(value)))
    }

    private suspend fun seed() {
        enqueue(MailboxPage(threads = listOf(summary), total = 1))
        mailbox.reload()
    }

    private fun reader(): ThreadViewModel = ThreadViewModel(
        api, summary.threadId, summary, temporary.newFolder(), "user", cache, dispatcher
    ).also { store.put("reader", it) }

    @Test fun openingUnreadMailUpdatesReaderAndMailboxWithoutListRefresh() = runTest(dispatcher) {
        seed()
        enqueue(detail)
        enqueue(MailActionResponse(ok = true))
        val reader = reader()
        reader.load { mailbox.onThreadLoaded(summary, it) }
        advanceUntilIdle()
        assertTrue(reader.state.value.isRead)
        assertTrue(mailbox.state.value.threads.single().isRead)
        assertTrue(cache.load(origin, "user", summary.threadId)!!.detail.messages.single().isRead)
        assertEquals(3, server.requestCount)
    }

    @Test fun serverReturningReadDetailAlsoUpdatesMailbox() = runTest(dispatcher) {
        seed()
        enqueue(detail.copy(messages = listOf(ThreadMessage(id = "message-1", isRead = true))))
        val reader = reader()
        reader.load { mailbox.onThreadLoaded(summary, it) }
        advanceUntilIdle()
        assertTrue(mailbox.state.value.threads.single().isRead)
        assertEquals(2, server.requestCount)
    }

    @Test fun failedAutomaticReadKeepsMailUnreadAndShowsConversation() = runTest(dispatcher) {
        seed()
        enqueue(detail)
        enqueue(MailActionResponse(ok = false))
        val reader = reader()
        reader.load { mailbox.onThreadLoaded(summary, it) }
        advanceUntilIdle()
        assertFalse(mailbox.state.value.threads.single().isRead)
        assertFalse(reader.state.value.isRead)
        assertNotNull(reader.state.value.detail)
        assertNotNull(reader.state.value.errorMessage)
        assertFalse(reader.state.value.isShowingSavedData)
    }

    @Test fun failedReaderMutationDoesNotPublishSuccessOrExit() = runTest(dispatcher) {
        enqueue(MailActionResponse(ok = false))
        val reader = reader()
        var notified = false
        var exited = false
        reader.perform(MailAction.Archive, { notified = true }, { exited = true })
        advanceUntilIdle()
        assertFalse(reader.state.value.isArchived)
        assertFalse(notified)
        assertFalse(exited)
        assertNotNull(reader.state.value.errorMessage)
    }

    @Test fun mutationsPreserveOtherFlagsFromCurrentRow() = runTest(dispatcher) {
        seed()
        mailbox.onThreadMutation(MailAction.Star, summary)
        mailbox.onThreadMutation(MailAction.Read, summary)
        assertTrue(mailbox.state.value.threads.single().isStarred)
        assertTrue(mailbox.state.value.threads.single().isRead)
        advanceUntilIdle()
    }

    @Test fun removingAnAlreadyAbsentRowDoesNotReduceTotalAgain() = runTest(dispatcher) {
        val other = summary.copy(threadId = "other")
        cache.save(detail.copy(threadId = "other"), origin, "user", "other")
        enqueue(MailboxPage(threads = listOf(summary, other), total = 2))
        mailbox.reload()
        mailbox.onThreadMutation(MailAction.Trash, summary)
        mailbox.onThreadMutation(MailAction.Delete, summary)
        assertEquals(1, mailbox.state.value.total)
        assertEquals("other", mailbox.state.value.threads.single().threadId)
        advanceUntilIdle()
    }

    @Test fun openedMailLeavesUnreadFilterImmediately() = runTest(dispatcher) {
        enqueue(MailboxPage(threads = listOf(summary), total = 1))
        mailbox.toggleUnreadOnly()
        advanceUntilIdle()
        mailbox.onThreadLoaded(summary, detail.copy(messages = listOf(ThreadMessage(id = "message-1", isRead = true))))
        assertTrue(mailbox.state.value.threads.isEmpty())
        assertEquals(0, mailbox.state.value.total)
        advanceUntilIdle()
    }

    @Test fun rapidReaderActionsSubmitOnlyOnce() = runTest(dispatcher) {
        enqueue(MailActionResponse(ok = true))
        val reader = reader()
        reader.perform(MailAction.Star, {})
        reader.perform(MailAction.Star, {})
        advanceUntilIdle()
        assertEquals(1, server.requestCount)
        assertTrue(reader.state.value.isStarred)
    }

    @Test fun lateListResponseCannotUndoAConfirmedRead() = runTest(dispatcher) {
        val delayedIo = QueuedDispatcher()
        val model = MailboxViewModel(api, "user", MailboxCache(temporary.newFolder(), gson), cache, delayedIo)
        store.put("delayed", model)
        fun pump() {
            repeat(6) { runCurrent(); delayedIo.runCurrent() }
            runCurrent()
        }
        enqueue(MailboxPage(threads = listOf(summary), total = 1))
        launch { model.reload() }
        pump()
        assertFalse(model.state.value.threads.single().isRead)

        enqueue(MailboxPage(threads = listOf(summary), total = 1))
        launch { model.reload() }
        runCurrent()
        delayedIo.runCurrent() // Old server response is waiting to reach the UI.
        model.onThreadMutation(MailAction.Read, summary)
        enqueue(MailboxPage(threads = listOf(summary.copy(isRead = true)), total = 1))
        runCurrent()
        assertTrue(model.state.value.threads.single().isRead)
        pump()
        assertTrue(model.state.value.threads.single().isRead)
        assertEquals(3, server.requestCount)
    }

    @Test fun oldSearchResponseIsIgnoredDuringDebounce() = runTest(dispatcher) {
        val delayedIo = QueuedDispatcher()
        val model = MailboxViewModel(api, "user", MailboxCache(temporary.newFolder(), gson), cache, delayedIo)
        store.put("delayed", model)
        enqueue(MailboxPage(threads = listOf(summary), total = 1))
        launch { model.reload() }
        runCurrent()
        delayedIo.runCurrent()
        model.onSearchChange("new query")
        runCurrent()
        assertEquals("new query", model.state.value.searchText)
        assertTrue(model.state.value.threads.isEmpty())
        store.clear() // Cancel the scheduled search; only the obsolete response is under test.
        repeat(3) { delayedIo.runCurrent(); runCurrent() }
    }

    @Test fun explicitUnreadAfterOpeningWinsOverAutomaticRead() = runTest(dispatcher) {
        enqueue(detail)
        enqueue(MailActionResponse(ok = true))
        enqueue(MailActionResponse(ok = true))
        val reader = reader()
        reader.load()
        reader.perform(MailAction.Unread, {})
        advanceUntilIdle()
        assertFalse(reader.state.value.isRead)
        assertFalse(reader.state.value.detail!!.messages.single().isRead)
        assertEquals(3, server.requestCount)
    }

    @Test fun mailboxMutationUpdatesSavedConversationWithoutDiscardingIt() = runTest(dispatcher) {
        seed()
        enqueue(MailActionResponse(ok = true))
        mailbox.perform(MailAction.Star, summary)
        advanceUntilIdle()
        val saved = cache.load(origin, "user", summary.threadId)!!.detail
        assertTrue(saved.messages.single().isStarred)
        assertEquals(detail.messages.single().id, saved.messages.single().id)
    }

    @Test fun starredFilterStaysWithinEachMailboxIncludingPagination() = runTest(dispatcher) {
        for (kind in MailboxKind.entries.filterNot { it == MailboxKind.Starred }) {
            if (kind != mailbox.state.value.mailbox) {
                enqueue(MailboxPage())
                mailbox.selectMailbox(kind)
                advanceUntilIdle()
                server.takeRequest()
            }
            enqueue(MailboxPage(threads = listOf(summary.copy(isStarred = true)), total = 2, pageCount = 2))
            mailbox.toggleStarredOnly()
            advanceUntilIdle()
            val first = server.takeRequest().requestUrl!!
            assertEquals(kind.apiValue, first.queryParameter("view"))
            assertEquals("1", first.queryParameter("starred"))
            assertEquals("1", first.queryParameter("page"))

            enqueue(MailboxPage(threads = listOf(summary.copy(isStarred = true)), total = 2, page = 2, pageCount = 2))
            mailbox.loadNextPage()
            advanceUntilIdle()
            val next = server.takeRequest().requestUrl!!
            assertEquals(kind.apiValue, next.queryParameter("view"))
            assertEquals("1", next.queryParameter("starred"))
            assertEquals("2", next.queryParameter("page"))
        }
    }

    @Test fun starredCombinesWithUnreadAndSearch() = runTest(dispatcher) {
        enqueue(MailboxPage())
        mailbox.onSearchChange("receipt")
        advanceUntilIdle()
        server.takeRequest()
        enqueue(MailboxPage())
        mailbox.toggleUnreadOnly()
        advanceUntilIdle()
        server.takeRequest()
        enqueue(MailboxPage())
        mailbox.toggleStarredOnly()
        advanceUntilIdle()
        val request = server.takeRequest().requestUrl!!
        assertEquals("inbox", request.queryParameter("view"))
        assertEquals("receipt", request.queryParameter("q"))
        assertEquals("1", request.queryParameter("unread"))
        assertEquals("1", request.queryParameter("starred"))
    }

    @Test fun unstarRemovesConversationFromStarredFilterImmediately() = runTest(dispatcher) {
        enqueue(MailboxPage(threads = listOf(summary.copy(isStarred = true)), total = 1))
        mailbox.toggleStarredOnly()
        advanceUntilIdle()
        mailbox.onThreadMutation(MailAction.Unstar, summary)
        assertTrue(mailbox.state.value.threads.isEmpty())
        assertEquals(0, mailbox.state.value.total)
        advanceUntilIdle()
    }

    @Test fun starredResultsDoNotReplaceTheFullOfflineInbox() = runTest(dispatcher) {
        seed()
        enqueue(MailboxPage())
        mailbox.toggleStarredOnly()
        advanceUntilIdle()
        assertTrue(mailbox.state.value.threads.isEmpty())
        assertEquals(listOf(summary), inboxCache.load(origin, "user")!!.threads)
    }

    @Test fun bulkReadActionUsesMajorityWithReadAsTieBreaker() {
        fun action(vararg read: Boolean) = selectionReadAction(read.map { summary.copy(isRead = it) })
        assertEquals(MailAction.Read, action(false, false))
        assertEquals(MailAction.Unread, action(true, true))
        assertEquals(MailAction.Read, action(false, false, true))
        assertEquals(MailAction.Unread, action(true, true, false))
        assertEquals(MailAction.Read, action(true, false))
    }
}

/** Holds IO completions so tests can change UI state before a response is delivered. */
private class QueuedDispatcher : CoroutineDispatcher() {
    private val queue = java.util.concurrent.ConcurrentLinkedQueue<Runnable>()
    override fun dispatch(context: CoroutineContext, block: Runnable) { queue.add(block) }
    fun runCurrent() {
        while (true) (queue.poll() ?: return).run()
    }
}
