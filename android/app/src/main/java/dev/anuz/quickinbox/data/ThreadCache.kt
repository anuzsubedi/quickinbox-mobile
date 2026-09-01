package dev.anuz.quickinbox.data

import android.content.Context
import com.google.gson.Gson
import dev.anuz.quickinbox.domain.ThreadDetail
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.security.MessageDigest
import java.util.Date

data class ThreadCacheSnapshot(
    val detail: ThreadDetail,
    val updatedAt: Date
)

class ThreadCache(
    private val directory: File,
    private val gson: Gson,
    private val nowMillis: () -> Long = System::currentTimeMillis,
    private val maxAgeMillis: Long = MAX_CACHE_AGE_MILLIS,
    private val maxEntriesPerAccount: Int = MAX_ENTRIES_PER_ACCOUNT
) {
    constructor(context: Context, gson: Gson) : this(File(context.cacheDir, "threads"), gson)

    companion object {
        const val MAX_CACHE_AGE_MILLIS = 24L * 60L * 60L * 1000L
        const val MAX_ENTRIES_PER_ACCOUNT = 64
    }

    private val lock = Any()

    init {
        require(maxAgeMillis >= 0) { "maxAgeMillis must not be negative" }
        require(maxEntriesPerAccount > 0) { "maxEntriesPerAccount must be positive" }
    }

    fun load(origin: String, userId: String, threadId: String): ThreadCacheSnapshot? {
        synchronized(lock) {
            val accountKey = accountKey(origin, userId)
            val file = fileFor(accountKey, threadId)
            val stored = readStored(file) ?: return null
            val now = nowMillis()
            if (stored.accountKey != accountKey ||
                stored.threadId != threadId ||
                !storedTimestampIsUsable(stored.updatedAt, now)
            ) {
                deleteQuietly(file)
                return null
            }
            val detail = try {
                gson.fromJson(stored.payload, ThreadDetail::class.java)?.takeIf { value ->
                    value.messages.all { it.id.isNotBlank() } &&
                        (value.threadId.isBlank() || value.threadId == threadId)
                }
            } catch (_: Exception) {
                null
            }
            if (detail == null) {
                deleteQuietly(file)
                return null
            }
            runCatching {
                writeStored(file, stored.copy(lastAccessedAt = now))
            }
            return ThreadCacheSnapshot(detail, Date(stored.updatedAt))
        }
    }

    fun save(detail: ThreadDetail, origin: String, userId: String, threadId: String) {
        synchronized(lock) {
            val now = nowMillis()
            require(now > 0) { "updatedAt must be positive" }
            require(threadId.isNotBlank()) { "threadId must not be blank" }
            val accountKey = accountKey(origin, userId)
            val stored = Stored(
                accountKey = accountKey,
                threadId = threadId,
                payload = gson.toJson(detail),
                updatedAt = now,
                lastAccessedAt = now
            )
            check(ensureDirectory()) { "Unable to create thread cache directory" }
            writeStored(fileFor(accountKey, threadId), stored)
            prune(accountKey)
        }
    }

    fun remove(origin: String, userId: String, threadId: String) {
        synchronized(lock) {
            deleteQuietly(fileFor(accountKey(origin, userId), threadId))
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

    private fun prune(accountKey: String) {
        val entries = directory.listFiles()
            ?.filter { it.isFile && it.extension == "json" }
            ?.mapNotNull { file ->
                val stored = readStored(file) ?: return@mapNotNull null
                if (stored.accountKey != accountKey) return@mapNotNull null
                if (!storedTimestampIsUsable(stored.updatedAt, nowMillis())) {
                    deleteQuietly(file)
                    return@mapNotNull null
                }
                file to stored
            }
            ?.sortedWith(
                compareByDescending<Pair<File, Stored>> { it.second.lastAccessedAt }
                    .thenByDescending { it.second.updatedAt }
                    .thenBy { it.first.name }
            )
            .orEmpty()
        entries.drop(maxEntriesPerAccount).forEach { (file, _) -> deleteQuietly(file) }
    }

    private fun readStored(file: File): Stored? {
        if (!file.isFile) return null
        return try {
            gson.fromJson(file.readText(), Stored::class.java)
                ?: run {
                    deleteQuietly(file)
                    null
                }
        } catch (_: Exception) {
            deleteQuietly(file)
            null
        }
    }

    private fun writeStored(target: File, stored: Stored) {
        val payload = gson.toJson(stored).toByteArray(Charsets.UTF_8)
        check(ensureDirectory()) { "Unable to create thread cache directory" }
        val temporary = File.createTempFile("${target.name}.", ".tmp", directory)
        try {
            FileOutputStream(temporary).use { output ->
                output.write(payload)
                output.flush()
                output.fd.sync()
            }
            if (!temporary.renameTo(target)) {
                throw IOException("Unable to atomically replace thread cache")
            }
        } finally {
            if (temporary.exists()) deleteQuietly(temporary)
        }
    }

    private fun storedTimestampIsUsable(updatedAt: Long, now: Long): Boolean =
        updatedAt > 0 && updatedAt <= now && now - updatedAt <= maxAgeMillis

    private fun ensureDirectory(): Boolean =
        directory.isDirectory || (directory.mkdirs() && directory.isDirectory)

    private fun deleteQuietly(file: File) {
        runCatching { file.deleteRecursively() }
    }

    private fun accountKey(origin: String, userId: String): String = hash("$origin|$userId")

    private fun fileFor(accountKey: String, threadId: String): File =
        File(directory, "${hash("$accountKey|$threadId")}.json")

    private fun hash(value: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray())
            .joinToString("") { "%02x".format(it) }

    private data class Stored(
        val accountKey: String = "",
        val threadId: String = "",
        val payload: String = "{}",
        val updatedAt: Long = 0,
        val lastAccessedAt: Long = updatedAt
    )
}
