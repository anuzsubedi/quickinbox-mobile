package dev.anuz.quickinbox

import dev.anuz.quickinbox.data.ATTACHMENT_CACHE_MAX_AGE_MS
import dev.anuz.quickinbox.data.ATTACHMENT_CACHE_MAX_FOLDERS
import dev.anuz.quickinbox.data.pruneAttachmentCache
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files

class AttachmentCacheTest {
    @Test
    fun pruneRemovesExpiredFoldersAndCapsRetainedDownloads() {
        val root = Files.createTempDirectory("quickinbox-attachments").toFile()
        val now = 2_000_000_000L
        try {
            val expired = root.resolve("expired").apply {
                mkdirs()
                resolve("partial").writeText("data")
                setLastModified(now - ATTACHMENT_CACHE_MAX_AGE_MS - 1)
            }
            val recent = (0..ATTACHMENT_CACHE_MAX_FOLDERS).map { index ->
                root.resolve("recent-$index").apply {
                    mkdirs()
                    setLastModified(now - index)
                }
            }

            pruneAttachmentCache(root, now)

            assertFalse(expired.exists())
            assertTrue(recent.take(ATTACHMENT_CACHE_MAX_FOLDERS).all { it.exists() })
            assertFalse(recent.last().exists())
        } finally {
            root.deleteRecursively()
        }
    }
}
