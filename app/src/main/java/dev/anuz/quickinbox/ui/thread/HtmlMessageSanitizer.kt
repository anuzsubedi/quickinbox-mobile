package dev.anuz.quickinbox.ui.thread

data class HtmlChromeColors(
    val canvas: String,
    val raised: String,
    val text: String,
    val secondary: String,
    val link: String
) {
    companion object {
        val Dark = HtmlChromeColors("#242426", "#3a3a3c", "#F2F2F7", "#CAC4D0", "#A8C7FA")
        val Light = HtmlChromeColors("#FFFFFF", "#FFFFFF", "#1C1B1F", "#625B71", "#0B57D0")
    }
}

object HtmlMessageSanitizer {
    private val blocked = listOf(
        "script", "iframe", "frame", "object", "embed", "form", "button",
        "input", "textarea", "select", "meta", "base", "link"
    )
    private val designedPattern = Regex("""<(?:table|style|center)\b|\bbgcolor\s*=""", RegexOption.IGNORE_CASE)
    private val authoredDarkModePattern = Regex(
        """@media[^\{]{0,240}\(\s*prefers-color-scheme\s*:\s*dark\s*\)|light-dark\s*\(""",
        RegexOption.IGNORE_CASE
    )
    private val declarationPattern = Regex(
        """\b(background(?:-color)?|color|border(?:-[a-z-]+)?|outline(?:-[a-z-]+)?)\s*:[^;}]*""",
        RegexOption.IGNORE_CASE
    )
    private val colorLiteralPattern = Regex(
        """#[0-9a-fA-F]{3,8}|rgba?\([^)]*\)""",
        RegexOption.IGNORE_CASE
    )
    private val attributePattern = Regex(
        """\b(bgcolor|color)\s*=\s*(["']?)(#[0-9a-fA-F]{3,8}|rgba?\([^)]*\))\2""",
        RegexOption.IGNORE_CASE
    )

    fun hasVisibleContent(html: String): Boolean {
        if (Regex("""<(?:svg\b|img\b[^>]*\bsrc\s*=\s*["']?\s*(?:data:|https?://))""", RegexOption.IGNORE_CASE).containsMatchIn(html)) {
            return true
        }
        val text = html
            .replace(Regex("""<(?:style|script|head)\b[^>]*>[\s\S]*?</(?:style|script|head)\s*>""", RegexOption.IGNORE_CASE), "")
            .replace(Regex("""<!--[\s\S]*?-->"""), "")
            .replace(Regex("""<[^>]+>"""), "")
            .replace("&nbsp;", " ")
            .replace("&#160;", " ")
            .replace(Regex("&#xA0;", RegexOption.IGNORE_CASE), " ")
            .replace("&zwnj;", "")
            .replace("&zwj;", "")
            .replace("\u200B", "")
            .replace("\uFEFF", "")
            .trim()
        return text.isNotEmpty()
    }

    fun containsRemoteImages(html: String): Boolean = Regex(
        """<(?:img|source|table|td|th|body)\b[^>]*\b(?:src|srcset|background)\s*=\s*["']?[^>]*(?:https?:)?//|url\s*\(\s*["']?(?:https?:)?//""",
        RegexOption.IGNORE_CASE
    ).containsMatchIn(html)

    fun document(
        rawHtml: String,
        loadsRemoteImages: Boolean,
        isDark: Boolean,
        chrome: HtmlChromeColors = if (isDark) HtmlChromeColors.Dark else HtmlChromeColors.Light
    ): String {
        var body = rawHtml
        val designed = designedPattern.containsMatchIn(rawHtml)
        val authoredDarkMode = authoredDarkModePattern.containsMatchIn(rawHtml)
        val viewport = if (designed) {
            "width=${designWidth(rawHtml)}, user-scalable=yes, minimum-scale=0.5, maximum-scale=5"
        } else {
            "width=device-width, initial-scale=1, user-scalable=yes, minimum-scale=0.5, maximum-scale=5"
        }

        var senderStyles = Regex("""<style\b[^>]*>([\s\S]*?)</style\s*>""", RegexOption.IGNORE_CASE)
            .findAll(body)
            .joinToString("\n") { sanitizeCss(it.groupValues[1], loadsRemoteImages) }

        for (element in blocked) {
            body = body.replace(Regex("""<$element\b[^>]*>[\s\S]*?</$element\s*>""", RegexOption.IGNORE_CASE), "")
            body = body.replace(Regex("""<$element\b[^>]*?/?>""", RegexOption.IGNORE_CASE), "")
        }
        body = body.replace(Regex("""\s+on[a-zA-Z]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)"""), "")
        body = body.replace(
            Regex("""\s+(?:srcdoc|contenteditable|autofocus)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)""", RegexOption.IGNORE_CASE),
            ""
        )
        body = body.replace(
            Regex("""\s+(?:href|src|poster|action)\s*=\s*(?:"|')?\s*(?:javascript|file):[^\s>]*(?:"|')?""", RegexOption.IGNORE_CASE),
            ""
        )
        body = body.replace(
            Regex("""<img\b[^>]*\bsrc\s*=\s*(?:"\s*cid:[^"]*"|'\s*cid:[^']*'|cid:[^\s>]+)[^>]*>""", RegexOption.IGNORE_CASE),
            ""
        )

        if (!loadsRemoteImages) {
            body = body.replace(
                Regex("""<picture\b[^>]*>[\s\S]*?(?:(?:https?:)?//)[\s\S]*?</picture\s*>""", RegexOption.IGNORE_CASE),
                ""
            )
            body = body.replace(
                Regex("""<(?:img|source)\b[^>]*\b(?:src|srcset)\s*=\s*(?:"[^"]*(?:(?:https?:)?//)[^"]*"|'[^']*(?:(?:https?:)?//)[^']*'|(?:https?:)?//[^\s>]+)[^>]*>""", RegexOption.IGNORE_CASE),
                ""
            )
            body = body.replace(
                Regex("""<tr\b[^>]*>\s*<td\b[^>]*>\s*</td\s*>\s*</tr\s*>""", RegexOption.IGNORE_CASE),
                ""
            )
            body = body.replace(
                Regex("""\s+(?:src|srcset|poster|background)\s*=\s*(?:"[^"]*(?:(?:https?:)?//)[^"]*"|'[^']*(?:(?:https?:)?//)[^']*'|(?:https?:)?//[^\s>]+)""", RegexOption.IGNORE_CASE),
                ""
            )
            body = removeRemoteCssUrls(body)
        }

        if (isDark && designed && !authoredDarkMode) {
            body = adaptDarkModeColors(body, chrome)
            senderStyles = adaptDarkModeColors(senderStyles, chrome)
        }
        body = body.replace(Regex("""<style\b[^>]*>[\s\S]*?</style\s*>""", RegexOption.IGNORE_CASE), "")

        val bodyAttributes = Regex("""<body\b([^>]*)>""", RegexOption.IGNORE_CASE)
            .find(body)?.groupValues?.get(1).orEmpty()
        val contents = Regex("""<body\b[^>]*>([\s\S]*?)</body\s*>""", RegexOption.IGNORE_CASE).find(body)
        body = contents?.groupValues?.get(1)
            ?: body.replace(Regex("""</?(?:html|head|body)\b[^>]*>""", RegexOption.IGNORE_CASE), "")

        val text = when {
            designed && !authoredDarkMode && !isDark -> "#111111"
            else -> chrome.text
        }
        val images = if (loadsRemoteImages) "https: http:" else ""
        val ordinaryStyles = if (designed) "" else ordinaryMessageStyles(isDark, chrome)
        val background = when {
            isDark || designed -> chrome.canvas
            else -> "transparent"
        }
        // Designed mail is authored on a fixed canvas. Keep that canvas intact so
        // the WebView can scale the whole message down. Forcing width:100% here
        // shrinks the outer table while inner cells stay 600px and get clipped.
        val canvasStyles = if (designed) """
            html, body { max-width: none !important; overflow-x: visible !important; }
            table { max-width: none !important; }
        """ else """
            html, body { max-width: 100% !important; overflow-x: hidden !important; }
            table { max-width: 100% !important; }
            body > table, body > div > table { width: 100% !important; }
        """

        return """
            <!doctype html>
            <html><head>
            <meta charset="utf-8">
            <meta name="viewport" content="$viewport">
            <meta name="color-scheme" content="light dark">
            <meta name="supported-color-schemes" content="light dark">
            <meta name="referrer" content="no-referrer">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: $images; style-src 'unsafe-inline'; font-src 'none'; media-src 'none'; frame-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'">
            <style>
            :root { color-scheme: light dark; }
            html, body {
                margin: 0 !important; padding: 0 !important;
                background: $background; color: $text; height: auto !important;
                overflow-y: hidden !important;
                -webkit-text-size-adjust: 100%;
            }
            body { font-family: Roboto, Arial, sans-serif; font-size: 16px; overflow-wrap: anywhere; word-break: normal; }
            body * { box-sizing: border-box !important; overflow-wrap: anywhere; }
            [style*="position: fixed" i], [style*="position:fixed" i],
            [style*="position: sticky" i], [style*="position:sticky" i] { position: static !important; }
            a, a:visited { color: ${chrome.link}; overflow-wrap: anywhere; }
            img, video, svg { max-width: 100% !important; height: auto !important; }
            pre, code { white-space: pre-wrap; overflow-wrap: anywhere; }
            pre { max-width: 100%; overflow-x: auto; }
            blockquote { margin-inline: 0.35em 0; padding-inline-start: 0.8em; border-inline-start: 3px solid ${chrome.secondary}; color: ${chrome.secondary}; }
            hr { border: 0; border-top: 1px solid ${chrome.secondary}; }
            $canvasStyles
            $ordinaryStyles
            </style>
            <style>$senderStyles</style>
            </head><body $bodyAttributes>$body</body></html>
        """.trimIndent()
    }

    private fun ordinaryMessageStyles(isDark: Boolean, chrome: HtmlChromeColors): String {
        val dark = if (isDark) """
            body { color: ${chrome.text} !important; background-color: transparent !important; }
            body *:not(a):not(img):not(video):not(picture):not(svg):not(source) {
                color: inherit !important; background-color: transparent !important; background-image: none !important;
            }
            a, a:visited { color: ${chrome.link} !important; }
            blockquote { color: ${chrome.secondary} !important; }
        """ else ""
        return """
            body { line-height: 1.45; }
            p { margin-block: 0 0.85em; }
            p:last-child { margin-bottom: 0; }
            $dark
            @media (prefers-color-scheme: dark) { $dark }
        """.trimIndent()
    }

    private fun sanitizeCss(css: String, loadsRemoteImages: Boolean): String {
        var result = css.replace(Regex("""@import[\s\S]*?;""", RegexOption.IGNORE_CASE), "")
        result = result.replace(Regex("""url\s*\(\s*["']?\s*(?:javascript|file):[^)]*\)""", RegexOption.IGNORE_CASE), "none")
        if (!loadsRemoteImages) {
            result = removeRemoteCssUrls(result)
            result = result.replace(Regex("""url\s*\(\s*["']?\s*cid:[^)]*\)""", RegexOption.IGNORE_CASE), "none")
        }
        return result.replace(Regex("""expression\s*\([^)]*\)""", RegexOption.IGNORE_CASE), "")
    }

    private fun removeRemoteCssUrls(value: String): String = value.replace(
        Regex("""url\s*\(\s*(?:"[^"]*(?:https?:)?//[^"]*"|'[^']*(?:https?:)?//[^']*'|(?:https?:)?//[^)]*)\)""", RegexOption.IGNORE_CASE),
        "none"
    )

    private fun designWidth(html: String): Int {
        val patterns = listOf(
            Regex("""\bwidth\s*=\s*["']?\s*(\d{3,4})(?:px)?\b""", RegexOption.IGNORE_CASE),
            Regex("""\bwidth\s*:\s*(\d{3,4})px\b""", RegexOption.IGNORE_CASE)
        )
        return patterns.flatMap { regex -> regex.findAll(html).mapNotNull { it.groupValues[1].toIntOrNull() }.toList() }
            .filter { it in 480..900 }
            .minOrNull() ?: 600
    }

    private fun adaptDarkModeColors(value: String, chrome: HtmlChromeColors): String {
        var result = declarationPattern.replace(value) { match ->
            val property = match.groupValues[1]
            colorLiteralPattern.replace(match.value) { color ->
                darkModeColor(color.value, property, chrome)
            }
        }
        result = attributePattern.replace(result) { match ->
            val property = match.groupValues[1]
            val literal = match.groupValues[3]
            match.value.replace(literal, darkModeColor(literal, property, chrome))
        }
        return result
    }

    private fun darkModeColor(literal: String, property: String, chrome: HtmlChromeColors): String {
        val (red, green, blue, alpha) = rgbaComponents(literal) ?: return literal
        if (alpha < 0.2) return literal
        val luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        val normalized = property.lowercase()
        val background = "background" in normalized || normalized == "bgcolor"
        return if (background) {
            when {
                luminance > 0.78 -> chrome.canvas
                luminance > 0.52 -> chrome.raised
                else -> literal
            }
        } else {
            when {
                luminance < 0.25 -> "#f2f2f7"
                luminance < 0.50 -> "#d1d1d6"
                else -> literal
            }
        }
    }

    private fun rgbaComponents(literal: String): Rgba? {
        val normalized = literal.lowercase()
        if (normalized.startsWith("#")) {
            val hex = normalized.drop(1)
            val expanded = when (hex.length) {
                3 -> hex.map { "$it$it" }.joinToString("") + "ff"
                4 -> hex.map { "$it$it" }.joinToString("")
                6 -> hex + "ff"
                8 -> hex
                else -> return null
            }
            val value = expanded.toLongOrNull(16) ?: return null
            return Rgba(
                red = ((value shr 24) and 0xffL) / 255.0,
                green = ((value shr 16) and 0xffL) / 255.0,
                blue = ((value shr 8) and 0xffL) / 255.0,
                alpha = (value and 0xffL) / 255.0
            )
        }
        val numbers = normalized
            .replace("rgba", "")
            .replace("rgb", "")
            .replace("(", "")
            .replace(")", "")
            .split(',')
            .mapNotNull { it.trim().toDoubleOrNull() }
        if (numbers.size < 3) return null
        return Rgba(
            red = (numbers[0] / 255).coerceIn(0.0, 1.0),
            green = (numbers[1] / 255).coerceIn(0.0, 1.0),
            blue = (numbers[2] / 255).coerceIn(0.0, 1.0),
            alpha = if (numbers.size > 3) numbers[3].coerceIn(0.0, 1.0) else 1.0
        )
    }

    private data class Rgba(val red: Double, val green: Double, val blue: Double, val alpha: Double)
}
