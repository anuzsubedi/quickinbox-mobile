package dev.anuz.quickinbox.data

import com.google.gson.Gson
import dev.anuz.quickinbox.domain.ThreadDetail
import dev.anuz.quickinbox.domain.ThreadMessage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.Date

class ThreadCacheTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun saveAndLoadRoundTripIsAccountScoped() {
        val now = 1_000_000L
        val cache = cache(now = { now })
        val detail = detail("thread-1", "Cached body")

        cache.save(detail, ORIGIN, USER_ID, "thread-1")

        val loaded = cache.load(ORIGIN, USER_ID, "thread-1")
        assertEquals(detail, loaded?.detail)
        assertEquals(Date(now), loaded?.updatedAt)
        assertNull(cache.load(ORIGIN, "another-user", "thread-1"))
        assertNull(cache.load("https://other.example", USER_ID, "thread-1"))
    }

    @Test
    fun staleAndCorruptEntriesAreRemoved() {
        var now = 2_000_000L
        val directory = temporaryFolder.newFolder("threads")
        val cache = ThreadCache(directory, Gson(), { now }, maxAgeMillis = 1_000L)
        cache.save(detail("stale", "Old"), ORIGIN, USER_ID, "stale")
        now += 1_001L

        assertNull(cache.load(ORIGIN, USER_ID, "stale"))
        assertTrue(directory.listFiles().orEmpty().isEmpty())

        cache.save(detail("corrupt", "Body"), ORIGIN, USER_ID, "corrupt")
        val file = directory.listFiles().orEmpty().single()
        file.writeText("not-json")

        assertNull(cache.load(ORIGIN, USER_ID, "corrupt"))
        assertFalse(file.exists())
    }

    @Test
    fun leastRecentlyUsedEntriesAreEvictedPerAccount() {
        var now = 3_000_000L
        val cache = cache(now = { now }, maxEntries = 2)
        cache.save(detail("thread-1", "One"), ORIGIN, USER_ID, "thread-1")
        now += 1
        cache.save(detail("thread-2", "Two"), ORIGIN, USER_ID, "thread-2")
        now += 1
        assertNotNull(cache.load(ORIGIN, USER_ID, "thread-1"))
        now += 1
        cache.save(detail("thread-3", "Three"), ORIGIN, USER_ID, "thread-3")

        assertNotNull(cache.load(ORIGIN, USER_ID, "thread-1"))
        assertNull(cache.load(ORIGIN, USER_ID, "thread-2"))
        assertNotNull(cache.load(ORIGIN, USER_ID, "thread-3"))

        cache.save(detail("other", "Other"), ORIGIN, "another-user", "other")
        assertNotNull(cache.load(ORIGIN, "another-user", "other"))
    }

    @Test
    fun clearAllRemovesEntriesAndStagingFiles() {
        val directory = temporaryFolder.newFolder("threads")
        val cache = ThreadCache(directory, Gson(), { 4_000_000L })
        cache.save(detail("thread-1", "Body"), ORIGIN, USER_ID, "thread-1")
        directory.resolve("orphan.tmp").writeText("partial")

        cache.clearAll()
        cache.clearAll()

        assertTrue(directory.isDirectory)
        assertTrue(directory.listFiles().orEmpty().isEmpty())
    }

    private fun cache(
        now: () -> Long,
        maxEntries: Int = ThreadCache.MAX_ENTRIES_PER_ACCOUNT
    ) = ThreadCache(
        temporaryFolder.newFolder(),
        Gson(),
        now,
        maxAgeMillis = 10_000L,
        maxEntriesPerAccount = maxEntries
    )

    private fun detail(threadId: String, body: String) = ThreadDetail(
        threadId = threadId,
        subject = "Subject",
        messages = listOf(ThreadMessage(id = "message-$threadId", bodyText = body))
    )

    private companion object {
        const val ORIGIN = "https://mail.example"
        const val USER_ID = "user-1"
    }
}
