package dev.anuz.quickinbox

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.gson.GsonBuilder
import dev.anuz.quickinbox.data.ApiDateAdapter
import dev.anuz.quickinbox.data.AppPreferences
import dev.anuz.quickinbox.data.AppSession
import dev.anuz.quickinbox.data.CredentialStore
import dev.anuz.quickinbox.data.MailboxCache
import dev.anuz.quickinbox.data.QuickInboxApi
import dev.anuz.quickinbox.data.SessionPhase
import dev.anuz.quickinbox.domain.Credential
import dev.anuz.quickinbox.domain.User
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Date

@RunWith(AndroidJUnit4::class)
class AppSessionInstrumentedTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val gson = GsonBuilder().registerTypeAdapter(Date::class.java, ApiDateAdapter()).create()
    private lateinit var server: MockWebServer
    private lateinit var credentials: CredentialStore
    private lateinit var preferences: AppPreferences
    private lateinit var cache: MailboxCache

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        credentials = CredentialStore(context, gson)
        preferences = AppPreferences(context, gson)
        cache = MailboxCache(context, gson)
        credentials.delete()
        preferences.clear()
        cache.clearAll()
    }

    @After
    fun tearDown() {
        credentials.delete()
        preferences.clear()
        cache.clearAll()
        server.shutdown()
    }

    @Test
    fun restoresSavedCredentialAndRefreshesCachedUser() = runBlocking {
        val user = User(id = "user-1", email = "user@example.com", name = "User")
        credentials.save(validCredential())
        server.enqueue(
            MockResponse().setResponseCode(200)
                .setBody("""{"user":{"id":"${user.id}","email":"${user.email}","name":"${user.name}"}}""")
        )
        val api = QuickInboxApi(gson)
        val session = AppSession(api, credentials, cache, preferences)
        api.onUnauthorized = session::handleUnauthorized

        session.bootstrapIfNeeded()

        val phase = session.phase.value
        assertTrue(phase is SessionPhase.Authenticated)
        assertEquals(user, (phase as SessionPhase.Authenticated).user)
        assertEquals(user, credentials.load()?.cachedUser)
    }

    @Test
    fun expiredCredentialIsRemovedWithoutNetworkRequest() = runBlocking {
        credentials.save(validCredential().copy(expiresAt = Date(System.currentTimeMillis() - 1)))
        val api = QuickInboxApi(gson)
        val session = AppSession(api, credentials, cache, preferences)
        api.onUnauthorized = session::handleUnauthorized

        session.bootstrapIfNeeded()

        assertTrue(session.phase.value is SessionPhase.Onboarding)
        assertNull(credentials.load())
        assertEquals(0, server.requestCount)
    }

    private fun validCredential() = Credential(
        origin = server.url("/").toString().trimEnd('/'),
        token = "session-token",
        expiresAt = Date(System.currentTimeMillis() + 60_000)
    )
}
