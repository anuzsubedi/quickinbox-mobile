package dev.anuz.quickinbox.domain

import java.text.DateFormat
import java.util.Calendar
import java.util.Date

fun Date.mailboxRelativeLabel(): String {
    val calendar = Calendar.getInstance()
    val now = Calendar.getInstance()
    calendar.time = this
    return when {
        now.get(Calendar.YEAR) == calendar.get(Calendar.YEAR) &&
            now.get(Calendar.DAY_OF_YEAR) == calendar.get(Calendar.DAY_OF_YEAR) ->
            DateFormat.getTimeInstance(DateFormat.SHORT).format(this)
        now.get(Calendar.YEAR) == calendar.get(Calendar.YEAR) &&
            now.get(Calendar.WEEK_OF_YEAR) == calendar.get(Calendar.WEEK_OF_YEAR) ->
            calendar.getDisplayName(Calendar.DAY_OF_WEEK, Calendar.SHORT, java.util.Locale.getDefault())
                ?: DateFormat.getDateInstance(DateFormat.MEDIUM).format(this)
        now.get(Calendar.YEAR) == calendar.get(Calendar.YEAR) -> {
            val month = calendar.getDisplayName(Calendar.MONTH, Calendar.SHORT, java.util.Locale.getDefault()).orEmpty()
            "$month ${calendar.get(Calendar.DAY_OF_MONTH)}"
        }
        else -> DateFormat.getDateInstance(DateFormat.MEDIUM).format(this)
    }
}

fun Date.sectionLabel(): String {
    val calendar = Calendar.getInstance()
    val now = Calendar.getInstance()
    calendar.time = this
    val days = (
        (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis - calendar.apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        ) / (24 * 60 * 60 * 1000)
    return when {
        days <= 0 -> "Today"
        days == 1L -> "Yesterday"
        days in 2..7 -> "Previous 7 Days"
        now.get(Calendar.YEAR) == Calendar.getInstance().apply { time = this@sectionLabel }.get(Calendar.YEAR) ->
            Calendar.getInstance().apply { time = this@sectionLabel }
                .getDisplayName(Calendar.MONTH, Calendar.LONG, java.util.Locale.getDefault())
                ?: DateFormat.getDateInstance(DateFormat.MEDIUM).format(this)
        else -> Calendar.getInstance().apply { time = this@sectionLabel }.get(Calendar.YEAR).toString()
    }
}

fun List<ThreadSummary>.groupedByDate(): List<Pair<String, List<ThreadSummary>>> {
    val grouped = linkedMapOf<String, MutableList<ThreadSummary>>()
    for (thread in this) {
        val label = thread.createdAt?.sectionLabel() ?: "Earlier"
        grouped.getOrPut(label) { mutableListOf() }.add(thread)
    }
    return grouped.map { it.key to it.value }
}

fun formatBytes(bytes: Int): String = when {
    bytes < 1024 -> "$bytes B"
    bytes < 1024 * 1024 -> "${bytes / 1024} KB"
    else -> String.format(java.util.Locale.getDefault(), "%.1f MB", bytes / (1024.0 * 1024.0))
}
