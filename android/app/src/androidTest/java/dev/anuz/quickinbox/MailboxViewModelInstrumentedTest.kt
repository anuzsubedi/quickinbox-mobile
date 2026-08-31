package dev.anuz.quickinbox

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.gson.GsonBuilder
import dev.anuz.quickinbox.data.ApiDateAdapter
import dev.anuz.quickinbox.data.MailboxCache
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.domain.Credential
import dev.anuz.quickinbox.ui.mailbox.MailboxViewModel
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
    private lateinit var api: QuickInboxApi

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        cache = MailboxCache(context, gson)
        cache.clearAll()
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
        server.shutdown()
    }

    @Test
    fun reloadPublishesMailboxPage() = runBlocking {
        server.enqueue(
            MockResponse().setResponseCode(200).setBody(
                """{"threads":[{"thread_id":"thread-1","latest_id":"message-1","subject":"Hello"}],"total":1,"page":1,"pageCount":1}"""
            )
        )
        val viewModel = MailboxViewModel(api, "user-1", cache)

        viewModel.reload()

        assertEquals(listOf("thread-1"), viewModel.state.value.threads.map { it.id })
        assertEquals(1, viewModel.state.value.total)
        assertFalse(viewModel.state.value.isInitialLoading)
        assertNull(viewModel.state.value.initialError)
    }
}
