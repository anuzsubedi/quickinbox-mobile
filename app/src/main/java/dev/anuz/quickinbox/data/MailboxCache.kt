package dev.anuz.quickinbox.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import dev.anuz.quickinbox.domain.ThreadSummary
import java.io.File
import java.security.MessageDigest
import java.util.Date

data class MailboxCacheSnapshot(
    val threads: List<ThreadSummary>,
    val total: Int,
    val pageCount: Int,
    val updatedAt: Date
)

class MailboxCache(context: Context, private val gson: Gson) {
    private val directory = File(context.cacheDir, "mailbox").apply { mkdirs() }

    fun load(origin: String, userId: String): MailboxCacheSnapshot? {
        val file = fileFor(origin, userId)
        if (!file.exists()) return null
        return try {
            gson.fromJson(file.readText(), Stored::class.java)?.let { stored ->
                val threads: List<ThreadSummary> = gson.fromJson(
                    stored.payload,
                    object : TypeToken<List<ThreadSummary>>() {}.type
                ) ?: return null
                if (threads.isEmpty()) return null
                MailboxCacheSnapshot(
                    threads = threads,
                    total = stored.total,
                    pageCount = maxOf(stored.pageCount, 1),
                    updatedAt = Date(stored.updatedAt)
                )
            }
        } catch (_: Exception) {
            null
        }
    }

    fun save(
        threads: List<ThreadSummary>,
        total: Int,
        pageCount: Int,
        origin: String,
        userId: String
    ) {
        val stored = Stored(
            payload = gson.toJson(threads),
            total = total,
            pageCount = maxOf(pageCount, 1),
            updatedAt = System.currentTimeMillis()
        )
        fileFor(origin, userId).writeText(gson.toJson(stored))
    }

    fun clearAll() {
        directory.listFiles()?.forEach { it.delete() }
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
