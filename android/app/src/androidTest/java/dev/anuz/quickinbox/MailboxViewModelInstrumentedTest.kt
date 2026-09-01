package dev.anuz.quickinbox

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.gson.GsonBuilder
import dev.anuz.quickinbox.data.ApiDateAdapter
import dev.anuz.quickinbox.data.MailboxCache
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.data.ThreadCache
import dev.anuz.quickinbox.domain.Credential
import dev.anuz.quickinbox.ui.mailbox.MailboxViewModel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Date

@RunWith(AndroidJUnit4::class)
class MailboxViewModelInstrumentedTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val gson = GsonBuilder().registerTypeAdapter(Date::class.java, ApiDateAdapter()).create()
    private lateinit var server: MockWebServer
    private lateinit var cache: MailboxCache
    private lateinit var threadCache: ThreadCache
    private lateinit var api: QuickInboxApi

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        cache = MailboxCache(context, gson)
        threadCache = ThreadCache(context, gson)
        cache.clearAll()
        threadCache.clearAll()
        api = QuickInboxApi(gson)
        api.install(
            Credential(
                origin = server.url("/").toString().trimEnd('/'),
                token = "token",
                expiresAt = Date(System.currentTimeMillis() + 60_000)
            )
        )
    }

    @After
    fun tearDown() {
        cache.clearAll()
        threadCache.clearAll()
        server.shutdown()
    }

    @Test
    fun reloadPublishesMailboxPage() = runBlocking {
        server.enqueue(
            MockResponse().setResponseCode(200).setBody(
                """{"threads":[{"thread_id":"thread-1","latest_id":"message-1","subject":"Hello"}],"total":1,"page":1,"pageCount":1}"""
            )
        )
        val viewModel = MailboxViewModel(api, "user-1", cache, threadCache)

        viewModel.reload()

        assertEquals(listOf("thread-1"), viewModel.state.value.threads.map { it.id })
        assertEquals(1, viewModel.state.value.total)
        assertFalse(viewModel.state.value.isInitialLoading)
        assertNull(viewModel.state.value.initialError)
    }

    @Test
    fun reloadPrefetchesConversationBodiesForOfflineReading() = runBlocking {
        server.enqueue(
            MockResponse().setResponseCode(200).setBody(
                """{"threads":[{"thread_id":"thread-1","latest_id":"message-1","subject":"Hello"}],"total":1,"page":1,"pageCount":1}"""
            )
        )
        server.enqueue(
            MockResponse().setResponseCode(200).setBody(
                """{"threadId":"thread-1","subject":"Hello","messages":[{"id":"message-1","body_text":"Cached body","is_read":true}]}"""
            )
        )
        val viewModel = MailboxViewModel(api, "user-1", cache, threadCache)

        viewModel.reload()

        val origin = requireNotNull(api.credential).origin
        withTimeout(5_000) {
            while (threadCache.load(origin, "user-1", "thread-1") == null) {
                kotlinx.coroutines.delay(50)
            }
        }
        assertNotNull(threadCache.load(origin, "user-1", "thread-1"))
    }

    @Test
    fun appendedPageIsPersistedWithItsPageNumber() = runBlocking {
        server.enqueue(
            MockResponse().setResponseCode(200).setBody(
                """{"threads":[{"thread_id":"thread-1","latest_id":"message-1"}],"total":2,"page":1,"pageCount":2}"""
            )
        )
        server.enqueue(
            MockResponse().setResponseCode(200).setBody(
                """{"threads":[{"thread_id":"thread-2","latest_id":"message-2"}],"total":2,"page":2,"pageCount":2}"""
            )
        )
        val viewModel = MailboxViewModel(api, "user-1", cache, threadCache)
        viewModel.reload()

        viewModel.loadNextPage()
        withTimeout(5_000) { viewModel.state.first { it.currentPage == 2 && !it.isAppending } }

        val saved = cache.load(requireNotNull(api.credential).origin, "user-1")
        assertEquals(listOf("thread-1", "thread-2"), saved?.threads?.map { it.id })
        assertEquals(2, saved?.currentPage)
    }
}
