import SwiftUI
import WebKit

/// Displays email HTML in an ephemeral, navigation-disabled WebKit surface.
///
/// JavaScript, cookies, forms, frames, and in-view navigation are disabled. Remote
/// images are loaded only after an explicit per-message choice or privacy preference.
/// The HTML is still treated as untrusted even though the server also sanitizes mail.
struct HardenedHTMLView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    let html: String
    var loadsRemoteImages = false
    @State private var contentHeight: CGFloat = 120

    var body: some View {
        HardenedWebView(
            html: HTMLMessageSanitizer.document(
                from: html,
                loadsRemoteImages: loadsRemoteImages
            ),
            colorScheme: colorScheme,
            openURL: { url in openURL(url) },
            height: $contentHeight
        )
            .frame(height: max(44, contentHeight))
    }
}

private struct HardenedWebView: UIViewRepresentable {
    let html: String
    let colorScheme: ColorScheme
    let openURL: (URL) -> Void
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, openURL: openURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = true
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        // Selection and native <details> disclosure remain available. Link and
        // window navigation is independently denied by the navigation delegates.
        webView.isUserInteractionEnabled = true
        context.coordinator.observeContentSize(of: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        context.coordinator.openURL = openURL
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        DispatchQueue.main.async { height = 44 }
        webView.loadHTMLString(html, baseURL: nil)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        coordinator.stopObservingContentSize()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        WKWebsiteDataStore.nonPersistent().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {}
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var height: CGFloat
        var loadedHTML: String?
        var openURL: (URL) -> Void
        private var contentSizeObservation: NSKeyValueObservation?
        private var restingZoomScale: CGFloat?

        init(height: Binding<CGFloat>, openURL: @escaping (URL) -> Void) {
            _height = height
            self.openURL = openURL
        }

        func observeContentSize(of webView: WKWebView) {
            contentSizeObservation = webView.scrollView.observe(
                \.contentSize,
                options: [.initial, .new]
            ) { [weak self] scrollView, change in
                guard let self,
                      !scrollView.isZooming,
                      !scrollView.isZoomBouncing else { return }

                if let restingZoomScale = self.restingZoomScale,
                   abs(scrollView.zoomScale - restingZoomScale) > 0.01 {
                    // Keep the SwiftUI container stable while the user is zoomed.
                    // Resizing it during a pinch changes WebKit's viewport and causes
                    // the content to jump or flash.
                    return
                }
                guard let measured = change.newValue?.height,
                      measured.isFinite,
                      measured > 0 else { return }
                DispatchQueue.main.async {
                    self.height = ceil(measured)
                }
            }
        }

        func stopObservingContentSize() {
            contentSizeObservation?.invalidate()
            contentSizeObservation = nil
            restingZoomScale = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            restingZoomScale = webView.scrollView.zoomScale
            let measured = webView.scrollView.contentSize.height
            if measured.isFinite, measured > 0 {
                height = ceil(measured)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url
            let isInitialDocument = navigationAction.navigationType == .other
                && (url?.scheme == "about" || url?.scheme == "data")
            if navigationAction.navigationType == .linkActivated,
               let url,
               Self.allowedExternalSchemes.contains(url.scheme?.lowercased() ?? "") {
                openURL(url)
            }
            decisionHandler(isInitialDocument ? .allow : .cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url,
               Self.allowedExternalSchemes.contains(url.scheme?.lowercased() ?? "") {
                openURL(url)
            }
            return nil
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard let loadedHTML else { return }
            webView.loadHTMLString(loadedHTML, baseURL: nil)
        }

        private static let allowedExternalSchemes = Set(["http", "https", "mailto", "tel"])
    }
}

nonisolated enum HTMLMessageSanitizer {
    static func document(
        from rawHTML: String,
        loadsRemoteImages: Bool = false
    ) -> String {
        var body = rawHTML
        let isDesignedMessage = rawHTML.range(
            of: #"<(?:table|style|center)\b|\bbgcolor\s*="#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        // A color-scheme declaration only opts into client-side adaptation; it
        // does not mean the sender supplied dark colors. Skip our fallback only
        // for actual dark-mode rules or adaptive color values.
        let hasAuthoredDarkMode = rawHTML.range(
            of: #"@media[^\{]{0,240}\(\s*prefers-color-scheme\s*:\s*dark\s*\)|light-dark\s*\("#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let viewportWidth = isDesignedMessage ? designWidth(in: rawHTML) : nil
        let viewport = viewportWidth.map {
            "width=\($0), user-scalable=yes, minimum-scale=0.5, maximum-scale=5"
        } ?? "width=device-width, initial-scale=1, user-scalable=yes, minimum-scale=0.5, maximum-scale=5"

        let senderStyles = matches(of: #"<style\b[^>]*>([\s\S]*?)</style\s*>"#, in: body)
            .map { sanitizeCSS($0, loadsRemoteImages: loadsRemoteImages) }
            .joined(separator: "\n")

        // Remove active and document-level elements before the content reaches WebKit.
        let blockedElements = ["script", "iframe", "frame", "object", "embed", "form", "button", "input", "textarea", "select", "meta", "base", "link"]
        for element in blockedElements {
            body = replacing(
                #"<\#(element)\b[^>]*>[\s\S]*?</\#(element)\s*>"#,
                in: body,
                with: ""
            )
            body = replacing(#"<\#(element)\b[^>]*?/?>"#, in: body, with: "")
        }

        body = replacing(#"\s+on[a-zA-Z]+\s*=\s*(?:\"[^\"]*\"|'[^']*'|[^\s>]+)"#, in: body, with: "")
        body = replacing(#"\s+(?:srcdoc|contenteditable|autofocus)\s*=\s*(?:\"[^\"]*\"|'[^']*'|[^\s>]+)"#, in: body, with: "")
        body = replacing(#"\s+(?:href|src|poster|action)\s*=\s*(?:\"|')?\s*(?:javascript|file):[^\s>]*(?:\"|')?"#, in: body, with: "")
        // CID images are MIME attachments, not network resources WebKit can
        // resolve in this isolated document. They are exposed in the native
        // attachment list instead of leaving a broken-image outline in-body.
        body = replacing(
            #"<img\b[^>]*\bsrc\s*=\s*(?:\"\s*cid:[^\"]*\"|'\s*cid:[^']*'|cid:[^\s>]+)[^>]*>"#,
            in: body,
            with: ""
        )
        if !loadsRemoteImages {
            body = replacing(#"\s+(?:src|srcset|poster|background)\s*=\s*(?:\"[^\"]*(?:(?:https?:)?//)[^\"]*\"|'[^']*(?:(?:https?:)?//)[^']*'|(?:https?:)?//[^\s>]+)"#, in: body, with: "")
            body = removingRemoteCSSURLs(from: body)
        }
        body = replacing(#"<style\b[^>]*>[\s\S]*?</style\s*>"#, in: body, with: "")

        let bodyAttributes = firstCapture(of: #"<body\b([^>]*)>"#, in: body) ?? ""
        if let bodyContents = firstCapture(of: #"<body\b[^>]*>([\s\S]*?)</body\s*>"#, in: body) {
            body = bodyContents
        } else {
            body = replacing(#"</?(?:html|head|body)\b[^>]*>"#, in: body, with: "")
        }

        return """
        <!doctype html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="\(viewport)">
        <meta name="color-scheme" content="light dark">
        <meta name="supported-color-schemes" content="light dark">
        <meta name="referrer" content="no-referrer">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: \(loadsRemoteImages ? "https: http:" : ""); style-src 'unsafe-inline'; font-src 'none'; media-src 'none'; frame-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'">
        <style>
        :root {
            color-scheme: light dark;
            --qm-text: -apple-system-label;
            --qm-secondary: -apple-system-secondary-label;
            --qm-link: -apple-system-link;
            --qm-rule: -apple-system-separator;
            --qm-quote: -apple-system-tertiary-system-fill;
        }
        html, body {
            margin: 0 !important;
            padding: 0 !important;
            max-width: 100% !important;
            background: \(isDesignedMessage && !hasAuthoredDarkMode ? "#ffffff" : "transparent");
            color: \(isDesignedMessage && !hasAuthoredDarkMode ? "#111111" : "var(--qm-text)");
            -webkit-text-size-adjust: 100%;
            height: auto !important;
            overflow-y: hidden !important;
            overflow-x: hidden !important;
        }
        body {
            font: -apple-system-body;
            overflow-wrap: anywhere;
            word-break: normal;
        }
        body * {
            box-sizing: border-box !important;
            overflow-wrap: anywhere;
        }
        [style*="position: fixed" i], [style*="position:fixed" i],
        [style*="position: sticky" i], [style*="position:sticky" i] {
            position: static !important;
        }
        a { color: var(--qm-link); overflow-wrap: anywhere; }
        img, video, svg { max-width: 100% !important; height: auto !important; }
        pre, code { white-space: pre-wrap; overflow-wrap: anywhere; }
        pre { max-width: 100%; overflow-x: auto; }
        blockquote {
            margin-inline: 0.35em 0;
            padding-inline-start: 0.8em;
            border-inline-start: 3px solid var(--qm-rule);
            color: var(--qm-secondary);
        }
        hr { border: 0; border-top: 1px solid var(--qm-rule); }
        table { max-width: 100% !important; }
        body > table, body > div > table { width: 100% !important; }
        \(isDesignedMessage && !hasAuthoredDarkMode ? designedMessageDarkModeStyles : "")
        \(isDesignedMessage ? "" : ordinaryMessageStyles)
        </style>
        <style>\(senderStyles)</style>
        </head><body \(bodyAttributes)>\(body)</body></html>
        """
    }

    static func hasVisibleContent(_ html: String) -> Bool {
        // Layout tables and unresolved CID images are common in attachment-only
        // messages. Only media this isolated WebView can actually render counts.
        if html.range(
            of: #"<svg\b|<img\b[^>]*\bsrc\s*=\s*[\"']?\s*(?:data:|https?://)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }
        let withoutNonContent = replacing(
            #"<(?:style|script|head)\b[^>]*>[\s\S]*?</(?:style|script|head)\s*>|<!--[\s\S]*?-->"#,
            in: html,
            with: ""
        )
        let text = replacing(#"<[^>]+>"#, in: withoutNonContent, with: "")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&#xA0;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&zwnj;", with: "")
            .replacingOccurrences(of: "&zwj;", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty
    }

    static func containsRemoteImages(_ html: String) -> Bool {
        html.range(
            of: #"<(?:img|source|table|td|th|body)\b[^>]*\b(?:src|srcset|background)\s*=\s*[\"']?[^>]*(?:https?:)?//|url\s*\(\s*[\"']?(?:https?:)?//"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func sanitizeCSS(_ css: String, loadsRemoteImages: Bool) -> String {
        var result = replacing(#"@import[\s\S]*?;"#, in: css, with: "")
        if loadsRemoteImages {
            result = replacing(#"url\s*\(\s*[\"']?\s*(?:javascript|file):[^)]*\)"#, in: result, with: "none")
        } else {
            result = removingRemoteCSSURLs(from: result)
            result = replacing(#"url\s*\(\s*[\"']?\s*(?:javascript|file|cid):[^)]*\)"#, in: result, with: "none")
        }
        result = replacing(#"expression\s*\([^)]*\)"#, in: result, with: "")
        return result
    }

    /// Ordinary correspondence often contains editor-generated black text or
    /// white backgrounds without being a deliberately designed email. Adapt
    /// those common defaults while leaving branded, table-based mail intact.
    private static let ordinaryMessageStyles = """
        body { line-height: 1.45; }
        p { margin-block: 0 0.85em; }
        p:last-child { margin-bottom: 0; }
        @media (prefers-color-scheme: dark) {
            [color="black" i], [color="#000" i], [color="#000000" i],
            [style*="color:black" i], [style*="color: black" i],
            [style*="color:#000" i], [style*="color: #000" i],
            [style*="color:rgb(0,0,0)" i], [style*="color: rgb(0, 0, 0)" i] {
                color: var(--qm-text) !important;
            }
            [bgcolor="white" i], [bgcolor="#fff" i], [bgcolor="#ffffff" i],
            [style*="background-color:white" i], [style*="background-color: white" i],
            [style*="background-color:#fff" i], [style*="background-color: #fff" i],
            [style*="background:white" i], [style*="background: white" i] {
                background-color: transparent !important;
            }
        }
        """

    /// Invert painted colors for designed messages that lack their own dark-mode
    /// styles. Images, videos, and similar media are re-inverted so they render
    /// with their original colors.
    private static let designedMessageDarkModeStyles = """
        @media (prefers-color-scheme: dark) {
            html {
                filter: invert(1) hue-rotate(180deg);
                -webkit-filter: invert(1) hue-rotate(180deg);
            }
            img, video, picture, svg, [background], [style*="background-image"] {
                filter: invert(1) hue-rotate(180deg);
                -webkit-filter: invert(1) hue-rotate(180deg);
            }
        }
        """

    private static func removingRemoteCSSURLs(from value: String) -> String {
        replacing(
            #"url\s*\(\s*(?:\"[^\"]*(?:https?:)?//[^\"]*\"|'[^']*(?:https?:)?//[^']*'|(?:https?:)?//[^)]*)\)"#,
            in: value,
            with: "none"
        )
    }

    /// Most marketing email is authored on a fixed 480–900 CSS-pixel canvas.
    /// Giving WebKit that canvas width lets it scale the entire message down to
    /// the actual reader width instead of clipping the right-hand side.
    private static func designWidth(in html: String) -> Int {
        let patterns = [
            #"\bwidth\s*=\s*[\"']?\s*(\d{3,4})(?:px)?\b"#,
            #"\bwidth\s*:\s*(\d{3,4})px\b"#
        ]
        let widths = patterns
            .flatMap { matches(of: $0, in: html) }
            .compactMap(Int.init)
            .filter { (480...900).contains($0) }
        return widths.min() ?? 600
    }

    private static func matches(of pattern: String, in value: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: value) else { return nil }
            return String(value[range])
        }
    }

    private static func firstCapture(of pattern: String, in value: String) -> String? {
        matches(of: pattern, in: value).first
    }

    private static func replacing(_ pattern: String, in value: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return value
        }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}

nonisolated struct HTMLMessageParts: Equatable, Sendable {
    let message: String
    let quotedHistory: String?
}

/// Separates common HTML reply wrappers so quoted mail can use native SwiftUI disclosure.
nonisolated enum HTMLQuotedContentParser {
    static func split(_ source: String) -> HTMLMessageParts {
        if source.range(of: #"<(?:html|table)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return HTMLMessageParts(message: source, quotedHistory: nil)
        }
        let patterns = [
            #"<(?:div|section)[^>]*(?:class|id)\s*=\s*["'][^"']*(?:gmail_quote|yahoo_quoted|protonmail_quote|divRplyFwdMsg)[^"']*["'][^>]*>"#,
            #"On\s+[^<\r\n]{1,240}\s+wrote:"#
        ]

        let candidates = patterns.compactMap { firstMatch(of: $0, in: source) }
        guard let boundary = candidates.min(by: { $0.lowerBound < $1.lowerBound }) else {
            return HTMLMessageParts(message: source, quotedHistory: nil)
        }

        let message = String(source[..<boundary.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let history = String(source[boundary.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasVisibleContent(message), hasVisibleContent(history) else {
            return HTMLMessageParts(message: source, quotedHistory: nil)
        }

        return HTMLMessageParts(message: message, quotedHistory: history)
    }

    private static func firstMatch(of pattern: String, in source: String) -> Range<String.Index>? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let fullRange = NSRange(source.startIndex..., in: source)
        guard let match = expression.firstMatch(in: source, range: fullRange) else { return nil }
        return Range(match.range, in: source)
    }

    private static func hasVisibleContent(_ html: String) -> Bool {
        let withoutTags = html.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        return !withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}
