package dev.anuz.quickinbox

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.gson.GsonBuilder
import dev.anuz.quickinbox.data.ApiDateAdapter
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.data.ThreadCache
import dev.anuz.quickinbox.domain.Credential
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.ThreadDetail
import dev.anuz.quickinbox.domain.ThreadMessage
import dev.anuz.quickinbox.ui.thread.ThreadViewModel
import kotlinx.coroutines.CompletableDeferred
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
import java.io.File
import java.util.Date
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class ThreadViewModelInstrumentedTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val gson = GsonBuilder().registerTypeAdapter(Date::class.java, ApiDateAdapter()).create()
    private lateinit var server: MockWebServer
    private lateinit var cache: ThreadCache
    private lateinit var api: QuickInboxApi
    private lateinit var cacheDirectory: File

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        cacheDirectory = File(context.cacheDir, "thread-viewmodel-tests")
        cache = ThreadCache(cacheDirectory, gson)
        cache.clearAll()
        api = QuickInboxApi(gson)
        api.install(
            Credential(
                origin = origin(),
                token = "token",
                expiresAt = Date(System.currentTimeMillis() + 60_000)
            )
        )
    }

    @After
    fun tearDown() {
        cache.clearAll()
        server.shutdown()
    }

    @Test
    fun cachedConversationRendersWhileNetworkRefreshes() = runBlocking {
        cache.save(detail("Saved body"), origin(), USER_ID, THREAD_ID)
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(threadJson("Fresh body"))
                .setBodyDelay(500, TimeUnit.MILLISECONDS)
        )
        val viewModel = viewModel()

        viewModel.load()

        val cachedState = withTimeout(5_000) {
            viewModel.state.first { it.isRefreshing && it.detail?.messages?.single()?.bodyText == "Saved body" }
        }
        assertEquals("Showing saved conversation · Refreshing", cachedState.savedDataMessage)

        val refreshedState = withTimeout(5_000) {
            viewModel.state.first { !it.isRefreshing && it.detail?.messages?.single()?.bodyText == "Fresh body" }
        }
        assertFalse(refreshedState.isShowingSavedData)
        assertNull(refreshedState.savedDataMessage)
        assertEquals("Fresh body", cache.load(origin(), USER_ID, THREAD_ID)?.detail?.messages?.single()?.bodyText)
    }

    @Test
    fun failedRefreshKeepsCachedConversation() = runBlocking {
        cache.save(detail("Saved body"), origin(), USER_ID, THREAD_ID)
        server.enqueue(MockResponse().setResponseCode(503).setBody("""{"error":"Unavailable"}"""))
        val viewModel = viewModel()

        viewModel.load()

        val state = withTimeout(5_000) {
            viewModel.state.first { it.savedDataMessage == "Showing saved conversation · Offline" }
        }
        assertEquals("Saved body", state.detail?.messages?.single()?.bodyText)
        assertNull(state.errorMessage)
        assertFalse(state.isLoading)
    }

    @Test
    fun permanentDeleteInvalidatesCachedConversation() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(200).setBody(threadJson("Body")))
        server.enqueue(MockResponse().setResponseCode(200).setBody("""{"ok":true}"""))
        val viewModel = viewModel()
        viewModel.load()
        withTimeout(5_000) { viewModel.state.first { it.detail != null && !it.isLoading } }
        assertNotNull(cache.load(origin(), USER_ID, THREAD_ID))
        val exited = CompletableDeferred<Unit>()

        viewModel.perform(MailAction.Delete, onMailboxMutation = {}, onExit = { exited.complete(Unit) })

        withTimeout(5_000) { exited.await() }
        assertNull(cache.load(origin(), USER_ID, THREAD_ID))
    }

    private fun viewModel() = ThreadViewModel(
        api = api,
        threadId = THREAD_ID,
        summary = null,
        cacheDirectory = cacheDirectory,
        userId = USER_ID,
        cache = cache
    )

    private fun detail(body: String) = ThreadDetail(
        threadId = THREAD_ID,
        subject = "Subject",
        messages = listOf(ThreadMessage(id = "message-1", bodyText = body, isRead = true))
    )

    private fun threadJson(body: String) =
        """{"threadId":"$THREAD_ID","subject":"Subject","messages":[{"id":"message-1","body_text":"$body","is_read":true}]}"""

    private fun origin() = server.url("/").toString().trimEnd('/')

    private companion object {
        const val USER_ID = "user-1"
        const val THREAD_ID = "thread-1"
    }
}
