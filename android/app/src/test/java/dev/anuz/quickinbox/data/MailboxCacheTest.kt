package dev.anuz.quickinbox.data

import com.google.gson.Gson
import dev.anuz.quickinbox.domain.ThreadSummary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.security.MessageDigest
import java.util.Date

class MailboxCacheTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun saveAndLoadRoundTripPreservesSnapshot() {
        val now = 1_000_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val cache = MailboxCache(directory, Gson(), { now }, maxAgeMillis = 10_000L)
        val thread = ThreadSummary(threadId = "thread-1", latestId = "message-1", subject = "Hello")

        cache.save(listOf(thread), 4, 3, ORIGIN, USER_ID, currentPage = 2)

        val loaded = cache.load(ORIGIN, USER_ID)
        assertNotNull(loaded)
        assertEquals(listOf(thread), loaded?.threads)
        assertEquals(4, loaded?.total)
        assertEquals(2, loaded?.currentPage)
        assertEquals(3, loaded?.pageCount)
        assertEquals(Date(now), loaded?.updatedAt)
    }

    @Test
    fun recordsWithoutCurrentPageRestoreAsFirstPage() {
        val now = 1_500_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val gson = Gson()
        val cache = MailboxCache(directory, gson, { now }, maxAgeMillis = 10_000L)
        writeStored(directory, gson, ORIGIN, USER_ID, now)

        val loaded = cache.load(ORIGIN, USER_ID)

        assertNotNull(loaded)
        assertEquals(1, loaded?.currentPage)
    }

    @Test
    fun saveReplacesExistingFileAndCleansTemporaryFile() {
        val now = 2_000_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val cache = MailboxCache(directory, Gson(), { now }, maxAgeMillis = 10_000L)
        val first = ThreadSummary(threadId = "thread-1", subject = "First")
        val second = ThreadSummary(threadId = "thread-2", subject = "Second")

        cache.save(listOf(first), 1, 1, ORIGIN, USER_ID)
        cache.save(listOf(second), 1, 1, ORIGIN, USER_ID)

        assertEquals(listOf(second), cache.load(ORIGIN, USER_ID)?.threads)
        assertEquals(1, directory.listFiles()?.size)
        assertTrue(directory.listFiles()?.single()?.name?.endsWith(".json") == true)
    }

    @Test
    fun staleCacheIsRejectedAndRemoved() {
        var now = 3_000_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val cache = MailboxCache(directory, Gson(), { now }, maxAgeMillis = 1_000L)
        cache.save(listOf(ThreadSummary(threadId = "thread-1")), 1, 1, ORIGIN, USER_ID)
        val cacheFile = cacheFile(directory, ORIGIN, USER_ID)

        now += 1_001L

        assertNull(cache.load(ORIGIN, USER_ID))
        assertFalse(cacheFile.exists())
    }

    @Test
    fun cacheAtFreshnessBoundaryIsAccepted() {
        var now = 4_000_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val cache = MailboxCache(directory, Gson(), { now }, maxAgeMillis = 1_000L)
        cache.save(listOf(ThreadSummary(threadId = "thread-1")), 1, 1, ORIGIN, USER_ID)
        now += 1_000L

        assertNotNull(cache.load(ORIGIN, USER_ID))
    }

    @Test
    fun invalidStoredTimestampsAreRejectedAndRemoved() {
        val now = 5_000_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val gson = Gson()
        val cache = MailboxCache(directory, gson, { now }, maxAgeMillis = 10_000L)

        listOf(0L, -1L, now + 1L).forEachIndexed { index, timestamp ->
            val origin = "https://timestamp-$index.example"
            writeStored(directory, gson, origin, USER_ID, timestamp)
            val file = cacheFile(directory, origin, USER_ID)

            assertNull(cache.load(origin, USER_ID))
            assertFalse(file.exists())
        }
    }

    @Test
    fun corruptCacheIsIgnoredAndRemoved() {
        val now = 6_000_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val cache = MailboxCache(directory, Gson(), { now }, maxAgeMillis = 10_000L)
        val file = cacheFile(directory, ORIGIN, USER_ID)
        file.writeText("not-json")

        assertNull(cache.load(ORIGIN, USER_ID))
        assertFalse(file.exists())
    }

    @Test
    fun clearAllRemovesCacheAndOrphanedStagingEntries() {
        val now = 7_000_000L
        val directory = temporaryFolder.newFolder("mailbox")
        val cache = MailboxCache(directory, Gson(), { now }, maxAgeMillis = 10_000L)
        cache.save(listOf(ThreadSummary(threadId = "thread-1")), 1, 1, ORIGIN, USER_ID)
        File(directory, "orphan.tmp").writeText("partial write")
        File(directory, "orphan-directory/nested.tmp").apply {
            requireNotNull(parentFile).mkdirs()
            writeText("partial write")
        }

        cache.clearAll()
        cache.clearAll()

        assertTrue(directory.isDirectory)
        assertTrue(directory.listFiles().orEmpty().isEmpty())
        assertNull(cache.load(ORIGIN, USER_ID))
    }

    @Test
    fun clearAllRemovesUnexpectedDirectoryPathWithoutThrowing() {
        val directory = temporaryFolder.newFile("mailbox")
        val cache = MailboxCache(directory, Gson(), { 8_000_000L }, maxAgeMillis = 10_000L)

        cache.clearAll()

        assertFalse(directory.exists())
    }

    private fun writeStored(
        directory: File,
        gson: Gson,
        origin: String,
        userId: String,
        updatedAt: Long
    ) {
        val threads = listOf(ThreadSummary(threadId = "thread-1"))
        cacheFile(directory, origin, userId).apply {
            requireNotNull(parentFile).mkdirs()
            writeText(
                gson.toJson(
                    mapOf(
                        "payload" to gson.toJson(threads),
                        "total" to threads.size,
                        "pageCount" to 1,
                        "updatedAt" to updatedAt
                    )
                )
            )
        }
    }

    private fun cacheFile(directory: File, origin: String, userId: String): File {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$origin|$userId".toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(directory, "$digest.json")
    }

    private companion object {
        const val ORIGIN = "https://mail.example"
        const val USER_ID = "user-1"
    }
}
