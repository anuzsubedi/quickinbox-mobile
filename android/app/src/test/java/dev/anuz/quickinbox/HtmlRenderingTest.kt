package dev.anuz.quickinbox

import dev.anuz.quickinbox.ui.thread.HtmlChromeColors
import dev.anuz.quickinbox.ui.thread.HtmlMessageSanitizer
import dev.anuz.quickinbox.ui.thread.HtmlQuotedContentParser
import dev.anuz.quickinbox.ui.thread.QuotedTextParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HtmlRenderingTest {
    @Test
    fun htmlQuoteIsSplitForOrdinaryReply() {
        val parts = HtmlQuotedContentParser.split(
            "<div>New response</div><div class=\"gmail_quote\">Old response</div>"
        )
        assertTrue(parts.message.contains("New response"))
        assertNotNull(parts.quotedHistory)
    }

    @Test
    fun designedTableMessageIsNotSplit() {
        val html = "<table><tr><td>On Monday someone wrote:</td></tr></table>"
        val parts = HtmlQuotedContentParser.split(html)
        assertEquals(html, parts.message)
        assertEquals(null, parts.quotedHistory)
    }

    @Test
    fun plainTextQuoteIsSplit() {
        val parts = QuotedTextParser.split("Thanks\n\nOn Monday, Person wrote:\n> Earlier")
        assertEquals("Thanks", parts.message)
        assertTrue(parts.quotedHistory?.contains("Earlier") == true)
    }

    @Test
    fun sanitizerBlocksActiveAndRemoteContent() {
        val document = HtmlMessageSanitizer.document(
            "<script>alert(1)</script><img src=\"https://tracker.test/pixel\"><p>Safe</p>",
            loadsRemoteImages = false,
            isDark = false
        )
        assertFalse(document.contains("alert(1)"))
        assertFalse(document.contains("tracker.test"))
        assertTrue(document.contains("<p>Safe</p>"))
        assertTrue(document.contains("default-src 'none'"))
    }

    @Test
    fun designedMessageUsesDetectedViewport() {
        val document = HtmlMessageSanitizer.document(
            "<table width=\"640\"><tr><td>Hello</td></tr></table>",
            loadsRemoteImages = false,
            isDark = false
        )
        assertTrue(document.contains("width=640, user-scalable=yes"))
        assertTrue(document.contains("supported-color-schemes"))
    }

    @Test
    fun designedDarkModeAdaptsHexRgbAndAttributes() {
        val document = HtmlMessageSanitizer.document(
            """<table bgcolor="#ffffff"><tr><td style="color: rgb(0, 0, 0); background-color: #b0b0b0 !important">Hello</td></tr></table>""",
            loadsRemoteImages = false,
            isDark = true
        )
        assertTrue(document.contains("#242426"))
        assertTrue(document.contains("#f2f2f7"))
        assertTrue(document.contains("#3a3a3c"))
        assertTrue(document.contains("!important"))
        assertFalse(document.contains("body > table, body > div > table { width: 100%"))
    }

    @Test
    fun lowAlphaColorsStayUnchanged() {
        val document = HtmlMessageSanitizer.document(
            """<table><tr><td style="color: rgba(0, 0, 0, 0.1)">Hello</td></tr></table>""",
            loadsRemoteImages = false,
            isDark = true
        )
        assertTrue(document.contains("rgba(0, 0, 0, 0.1)"))
    }

    @Test
    fun authoredDarkModeSkipsFallbackAdaptation() {
        val document = HtmlMessageSanitizer.document(
            """<style>@media (prefers-color-scheme: dark) { p { color: #eee } }</style><table bgcolor="#ffffff"><tr><td>Hello</td></tr></table>""",
            loadsRemoteImages = false,
            isDark = true
        )
        assertTrue(document.contains("bgcolor=\"#ffffff\"") || document.contains("#ffffff"))
        assertFalse(Regex("""bgcolor\s*=\s*["']?#242426""", RegexOption.IGNORE_CASE).containsMatchIn(document))
    }

    @Test
    fun darkModeUsesThemeCanvasForDesignedMail() {
        val chrome = HtmlChromeColors(
            canvas = "#1A1514",
            raised = "#2A2422",
            text = "#E8E2DF",
            secondary = "#C8C2BF",
            link = "#D4A59A"
        )
        val document = HtmlMessageSanitizer.document(
            """<table bgcolor="#ffffff"><tr><td style="color: #000000">Hello</td></tr></table>""",
            loadsRemoteImages = false,
            isDark = true,
            chrome = chrome
        )
        assertTrue(document.contains("#1A1514"))
        assertFalse(document.contains("#242426"))
    }
}
