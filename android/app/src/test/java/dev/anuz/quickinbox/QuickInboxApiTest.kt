package dev.anuz.quickinbox

import com.google.gson.GsonBuilder
import dev.anuz.quickinbox.data.ApiDateAdapter
import dev.anuz.quickinbox.data.ApiError
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.domain.Credential
import dev.anuz.quickinbox.domain.MailboxKind
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Date

class QuickInboxApiTest {
    private lateinit var server: MockWebServer
    private lateinit var api: QuickInboxApi

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        val gson = GsonBuilder().registerTypeAdapter(Date::class.java, ApiDateAdapter()).create()
        api = QuickInboxApi(gson)
        api.install(
            Credential(
                origin = server.url("/").toString().trimEnd('/'),
                token = "test-token",
                expiresAt = Date(System.currentTimeMillis() + 60_000)
            )
        )
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun listThreadsBuildsAuthenticatedRequest() {
        server.enqueue(
            MockResponse().setResponseCode(200)
                .setHeader("Content-Type", "application/json")
                .setBody("""{"threads":[],"total":0,"page":1,"pageCount":1}""")
        )

        val page = api.listThreads(MailboxKind.Inbox)

        assertEquals(1, page.page)
        val request = server.takeRequest()
        assertEquals("/api/mail?view=inbox&page=1", request.path)
        assertEquals("Bearer test-token", request.getHeader("Authorization"))
    }

    @Test
    fun unauthorizedResponseNotifiesSessionAndMapsError() {
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":"expired"}"""))
        var unauthorizedCount = 0
        api.onUnauthorized = { unauthorizedCount += 1 }

        assertThrows(ApiError.Unauthorized::class.java) { api.currentUser() }

        assertEquals(1, unauthorizedCount)
    }

    @Test
    fun malformedSuccessfulResponseMapsToDecodingError() {
        server.enqueue(MockResponse().setResponseCode(200).setBody("{"))

        assertThrows(ApiError.Decoding::class.java) { api.currentUser() }
    }

    @Test
    fun expiredCredentialFailsBeforeNetworkCall() {
        api.install(
            Credential(
                origin = server.url("/").toString().trimEnd('/'),
                token = "expired",
                expiresAt = Date(System.currentTimeMillis() - 1)
            )
        )

        assertThrows(ApiError.Unauthorized::class.java) { api.currentUser() }
        assertEquals(0, server.requestCount)
        assertTrue(api.credential?.isExpired == true)
    }
}
