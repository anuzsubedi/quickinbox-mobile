package dev.anuz.quickinbox.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import dev.anuz.quickinbox.domain.ThreadSummary
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.security.MessageDigest
import java.util.Date

data class MailboxCacheSnapshot(
    val threads: List<ThreadSummary>,
    val total: Int,
    val pageCount: Int,
    val updatedAt: Date
)

class MailboxCache(
    private val directory: File,
    private val gson: Gson,
    private val nowMillis: () -> Long = System::currentTimeMillis,
    private val maxAgeMillis: Long = MAX_CACHE_AGE_MILLIS
) {
    constructor(context: Context, gson: Gson) : this(File(context.cacheDir, "mailbox"), gson)

    companion object {
        /** Cached inbox data is an offline fallback and is never older than one day. */
        const val MAX_CACHE_AGE_MILLIS = 24L * 60L * 60L * 1000L
    }

    private val lock = Any()

    init {
        require(maxAgeMillis >= 0) { "maxAgeMillis must not be negative" }
    }

    fun load(origin: String, userId: String): MailboxCacheSnapshot? {
        synchronized(lock) {
            val file = fileFor(origin, userId)
            if (!file.isFile) return null
            return try {
                val stored = gson.fromJson(file.readText(), Stored::class.java)
                    ?: run {
                        deleteQuietly(file)
                        return null
                    }
                val now = nowMillis()
                if (!storedTimestampIsUsable(stored.updatedAt, now)) {
                    deleteQuietly(file)
                    return null
                }
                val threads: List<ThreadSummary?> = gson.fromJson(
                    stored.payload,
                    object : TypeToken<List<ThreadSummary?>>() {}.type
                ) ?: run {
                    deleteQuietly(file)
                    return null
                }
                if (threads.isEmpty() || threads.any { it == null } || stored.total < 0) {
                    deleteQuietly(file)
                    return null
                }
                MailboxCacheSnapshot(
                    threads = threads.filterNotNull(),
                    total = stored.total,
                    pageCount = maxOf(stored.pageCount, 1),
                    updatedAt = Date(stored.updatedAt)
                )
            } catch (_: Exception) {
                deleteQuietly(file)
                null
            }
        }
    }

    fun save(
        threads: List<ThreadSummary>,
        total: Int,
        pageCount: Int,
        origin: String,
        userId: String
    ) {
        synchronized(lock) {
            val updatedAt = nowMillis()
            require(updatedAt > 0) { "updatedAt must be positive" }
            val stored = Stored(
                payload = gson.toJson(threads),
                total = total,
                pageCount = maxOf(pageCount, 1),
                updatedAt = updatedAt
            )
            val payload = gson.toJson(stored).toByteArray(Charsets.UTF_8)
            check(ensureDirectory()) { "Unable to create mailbox cache directory" }
            val target = fileFor(origin, userId)
            val temporary = File.createTempFile("${target.name}.", ".tmp", directory)
            try {
                FileOutputStream(temporary).use { output ->
                    output.write(payload)
                    output.flush()
                    output.fd.sync()
                }
                if (!temporary.renameTo(target)) {
                    throw IOException("Unable to atomically replace mailbox cache")
                }
            } finally {
                if (temporary.exists()) deleteQuietly(temporary)
            }
        }
    }

    fun clearAll() {
        synchronized(lock) {
            if (!directory.exists()) return
            if (!directory.isDirectory) {
                deleteQuietly(directory)
                return
            }
            directory.listFiles()?.forEach(::deleteQuietly)
        }
    }

    private fun storedTimestampIsUsable(updatedAt: Long, now: Long): Boolean =
        updatedAt > 0 && updatedAt <= now && now - updatedAt <= maxAgeMillis

    private fun ensureDirectory(): Boolean =
        directory.isDirectory || (directory.mkdirs() && directory.isDirectory)

    private fun deleteQuietly(file: File) {
        runCatching { file.deleteRecursively() }
    }

    private fun fileFor(origin: String, userId: String): File {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$origin|$userId".toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(directory, "$digest.json")
    }

    private data class Stored(
        val payload: String = "[]",
        val total: Int = 0,
        val pageCount: Int = 1,
        val updatedAt: Long = 0
    )
}
