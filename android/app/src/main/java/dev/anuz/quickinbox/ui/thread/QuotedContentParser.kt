package dev.anuz.quickinbox.ui.thread

data class HtmlMessageParts(val message: String, val quotedHistory: String?)

object HtmlQuotedContentParser {
    private val designedDocument = Regex("""<(?:html|table)\b""", RegexOption.IGNORE_CASE)
    private val boundaries = listOf(
        Regex(
            """<(?:div|section)[^>]*(?:class|id)\s*=\s*["'][^"']*(?:gmail_quote|yahoo_quoted|protonmail_quote|divRplyFwdMsg)[^"']*["'][^>]*>""",
            RegexOption.IGNORE_CASE
        ),
        Regex("""On\s+[^<\r\n]{1,240}\s+wrote:""", RegexOption.IGNORE_CASE)
    )

    fun split(source: String): HtmlMessageParts {
        // Full/table-designed messages frequently contain these tokens as layout
        // content. Preserve them intact rather than risking a destructive split.
        if (designedDocument.containsMatchIn(source)) return HtmlMessageParts(source, null)
        val boundary = boundaries.mapNotNull { it.find(source)?.range?.first }.minOrNull()
            ?: return HtmlMessageParts(source, null)
        val message = source.substring(0, boundary).trim()
        val history = source.substring(boundary).trim()
        return if (visible(message) && visible(history)) HtmlMessageParts(message, history)
        else HtmlMessageParts(source, null)
    }

    private fun visible(html: String): Boolean = html
        .replace(Regex("""<[^>]+>"""), "")
        .replace("&nbsp;", " ")
        .trim()
        .isNotEmpty()
}

data class TextMessageParts(val message: String, val quotedHistory: String?)

object QuotedTextParser {
    fun split(source: String): TextMessageParts {
        val normalized = source.replace("\r\n", "\n").replace('\r', '\n')
        val lines = normalized.lines()
        val boundary = lines.indices.firstOrNull { index -> isBoundary(lines, index) }
            ?: return TextMessageParts(normalized.trim(), null)
        if (boundary == 0) return TextMessageParts(normalized.trim(), null)
        val message = lines.take(boundary).joinToString("\n").trim()
        val history = lines.drop(boundary).joinToString("\n").trim()
        return if (message.isNotEmpty() && history.isNotEmpty()) TextMessageParts(message, history)
        else TextMessageParts(normalized.trim(), null)
    }

    private fun isBoundary(lines: List<String>, index: Int): Boolean {
        val line = lines[index].trim()
        val lower = line.lowercase()
        if (line.startsWith(">") || lower == "-----original message-----") return true
        if (lower.startsWith("on ") && lower.endsWith(" wrote:")) return true
        if (!lower.startsWith("from:")) return false
        val headers = lines.subList(index, minOf(lines.size, index + 6)).map { it.trim().lowercase() }
        return headers.any { it.startsWith("to:") } &&
            headers.any { it.startsWith("date:") || it.startsWith("sent:") || it.startsWith("subject:") }
    }
}
