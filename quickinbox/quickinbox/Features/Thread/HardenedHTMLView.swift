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
    @State private var contentHeight: CGFloat = 44

    var body: some View {
        HardenedWebView(
            html: HTMLMessageSanitizer.document(
                from: html,
                loadsRemoteImages: loadsRemoteImages,
                isDarkMode: colorScheme == .dark
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
        // JavaScript is enabled only so the app can measure the sanitized
        // document body. Sender scripts are stripped before loading and the
        // generated CSP denies script sources.
        preferences.allowsContentJavaScript = true

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
        // The surrounding SwiftUI thread owns vertical scrolling. Keeping a
        // second scroll container here makes WebKit report viewport height as
        // document height for complex forwarded mail.
        webView.scrollView.isScrollEnabled = false
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
        private var measurementWorkItem: DispatchWorkItem?
        private var restingZoomScale: CGFloat?

        init(height: Binding<CGFloat>, openURL: @escaping (URL) -> Void) {
            _height = height
            self.openURL = openURL
        }

        func observeContentSize(of webView: WKWebView) {
            contentSizeObservation = webView.scrollView.observe(
                \.contentSize,
                options: [.initial, .new]
            ) { [weak self, weak webView] scrollView, _ in
                guard let self, let webView,
                      !scrollView.isZooming,
                      !scrollView.isZoomBouncing else { return }

                if let restingZoomScale = self.restingZoomScale,
                   abs(scrollView.zoomScale - restingZoomScale) > 0.01 {
                    // Keep the SwiftUI container stable while the user is zoomed.
                    // Resizing it during a pinch changes WebKit's viewport and causes
                    // the content to jump or flash.
                    return
                }
                self.scheduleDocumentHeightMeasurement(in: webView)
            }
        }

        func stopObservingContentSize() {
            measurementWorkItem?.cancel()
            measurementWorkItem = nil
            contentSizeObservation?.invalidate()
            contentSizeObservation = nil
            restingZoomScale = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            restingZoomScale = webView.scrollView.zoomScale
            scheduleDocumentHeightMeasurement(in: webView)
        }

        private func scheduleDocumentHeightMeasurement(in webView: WKWebView) {
            measurementWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView else { return }
                let script = """
                (() => {
                    const body = document.body;
                    if (!body) return 0;
                    // scrollHeight/offsetHeight are never smaller than the
                    // current WebView viewport. Using either one here feeds an
                    // old oversized frame back into SwiftUI forever. Place a
                    // zero-height marker after normal-flow content, then include
                    // out-of-flow descendants such as positioned elements.
                    const bodyRect = body.getBoundingClientRect();
                    const bodyTop = bodyRect.top + window.scrollY;
                    const marker = document.createElement('div');
                    marker.style.cssText = 'display:block;width:0;height:0;padding:0;margin:0;clear:both;';
                    body.appendChild(marker);
                    let bottom = marker.getBoundingClientRect().bottom + window.scrollY;
                    marker.remove();
                    for (const element of body.querySelectorAll('*')) {
                        const rect = element.getBoundingClientRect();
                        if (rect.width > 0 && rect.height > 0) {
                            bottom = Math.max(bottom, rect.bottom + window.scrollY);
                        }
                    }
                    return {
                        height: Math.max(44, bottom - bodyTop),
                        viewportWidth: Math.max(window.innerWidth, 1)
                    };
                })()
                """
                let nativeViewportWidth = webView.bounds.width
                webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
                    guard let self,
                          let values = result as? [String: Any],
                          let cssHeight = (values["height"] as? NSNumber)?.doubleValue,
                          let cssViewportWidth = (values["viewportWidth"] as? NSNumber)?.doubleValue,
                          cssHeight.isFinite,
                          cssHeight > 0,
                          cssViewportWidth.isFinite,
                          cssViewportWidth > 0 else { return }
                    // The DOM reports CSS pixels while SwiftUI frames UIKit in
                    // points. Fixed-width email viewport metadata makes these
                    // scales differ; convert before updating the frame.
                    let scale = nativeViewportWidth > 0
                        ? nativeViewportWidth / cssViewportWidth
                        : (webView?.bounds.width ?? 0) / cssViewportWidth
                    let measured = cssHeight * (scale > 0 && scale.isFinite ? scale : 1)
                    DispatchQueue.main.async {
                        self.height = ceil(measured)
                    }
                }
            }
            measurementWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: workItem)
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
        loadsRemoteImages: Bool = false,
        isDarkMode: Bool = false
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
            .map { style in
                let sanitized = sanitizeCSS(style, loadsRemoteImages: loadsRemoteImages)
                return isDarkMode && isDesignedMessage && !hasAuthoredDarkMode
                    ? adaptDarkModeColors(in: sanitized)
                    : sanitized
            }
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
            // Remove remote media elements entirely so withheld images do not
            // leave broken-image outlines or alt text in the message body.
            body = replacing(
                #"<picture\b[^>]*>[\s\S]*?(?:(?:https?:)?//)[\s\S]*?</picture\s*>"#,
                in: body,
                with: ""
            )
            body = replacing(
                #"<(?:img|source)\b[^>]*\b(?:src|srcset)\s*=\s*(?:\"[^\"]*(?:(?:https?:)?//)[^\"]*\"|'[^']*(?:(?:https?:)?//)[^']*'|(?:https?:)?//[^\s>]+)[^>]*>"#,
                in: body,
                with: ""
            )
            // Newsletter images are often the only content in a table row.
            // Remove the now-empty row as well so its original media slot does
            // not remain as blank document height.
            body = replacing(
                #"<tr\b[^>]*>\s*<td\b[^>]*>\s*</td\s*>\s*</tr\s*>"#,
                in: body,
                with: ""
            )
            body = replacing(#"\s+(?:src|srcset|poster|background)\s*=\s*(?:\"[^\"]*(?:(?:https?:)?//)[^\"]*\"|'[^']*(?:(?:https?:)?//)[^']*'|(?:https?:)?//[^\s>]+)"#, in: body, with: "")
            body = removingRemoteCSSURLs(from: body)
        }
        if isDarkMode && isDesignedMessage && !hasAuthoredDarkMode {
            body = adaptDarkModeColors(in: body)
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
            background: \(isDesignedMessage && !hasAuthoredDarkMode && !isDarkMode ? "#ffffff" : "transparent");
            color: \(isDesignedMessage && !hasAuthoredDarkMode && !isDarkMode ? "#111111" : "var(--qm-text)");
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
        \(isDesignedMessage ? "" : ordinaryMessageStyles(isDarkMode: isDarkMode))
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
    private static func ordinaryMessageStyles(isDarkMode: Bool) -> String {
        let darkModeStyles = isDarkMode ? """
            body {
                color: #f2f2f7 !important;
                background-color: transparent !important;
            }
            body *:not(a):not(img):not(video):not(picture):not(svg):not(source) {
                color: inherit !important;
                background-color: transparent !important;
                background-image: none !important;
            }
            a, a:visited { color: #64a8ff !important; }
            blockquote { color: #aeaeb2 !important; }
            """ : ""
        return """
        body { line-height: 1.45; }
        p { margin-block: 0 0.85em; }
        p:last-child { margin-bottom: 0; }
        \(darkModeStyles)
        @media (prefers-color-scheme: dark) {
            \(darkModeStyles)
        }
        """
    }

    /// Darken light sender-authored canvas colors without inverting an entire
    /// designed message. Gmail-style thresholding keeps existing dark sections
    /// dark and leaves images untouched.
    private static func adaptDarkModeColors(in value: String) -> String {
        guard let declarationExpression = try? NSRegularExpression(
            pattern: #"\b(background(?:-color)?|color|border(?:-[a-z-]+)?|outline(?:-[a-z-]+)?)\s*:[^;}]*"#,
            options: [.caseInsensitive]
        ) else { return value }

        var result = value
        let fullRange = NSRange(value.startIndex..., in: value)
        let declarations = declarationExpression.matches(in: value, range: fullRange).reversed()
        for match in declarations {
            guard let range = Range(match.range, in: value),
                  let propertyRange = Range(match.range(at: 1), in: value) else { continue }
            let declaration = String(value[range])
            let property = String(value[propertyRange])
            let adapted = replaceColorLiterals(
                in: declaration,
                property: property
            )
            result.replaceSubrange(range, with: adapted)
        }

        guard let attributeExpression = try? NSRegularExpression(
            pattern: #"\b(bgcolor|color)\s*=\s*([\"']?)(#[0-9a-f]{3,8}|rgba?\([^)]*\))\2"#,
            options: [.caseInsensitive]
        ) else { return result }
        let attributeRange = NSRange(result.startIndex..., in: result)
        for match in attributeExpression.matches(in: result, range: attributeRange).reversed() {
            guard let propertyRange = Range(match.range(at: 1), in: result),
                  let colorRange = Range(match.range(at: 3), in: result) else { continue }
            let property = String(result[propertyRange])
            let literal = String(result[colorRange])
            result.replaceSubrange(colorRange, with: darkModeColor(literal, property: property))
        }
        return result
    }

    private static func replaceColorLiterals(in declaration: String, property: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: #"#[0-9a-f]{3,8}|rgba?\([^)]*\)"#,
            options: [.caseInsensitive]
        ) else { return declaration }
        var result = declaration
        let range = NSRange(declaration.startIndex..., in: declaration)
        for match in expression.matches(in: declaration, range: range).reversed() {
            guard let literalRange = Range(match.range, in: declaration) else { continue }
            let literal = String(declaration[literalRange])
            result.replaceSubrange(literalRange, with: darkModeColor(literal, property: property))
        }
        return result
    }

    private static func darkModeColor(_ literal: String, property: String) -> String {
        guard let (red, green, blue, alpha) = rgbaComponents(from: literal), alpha >= 0.2 else {
            return literal
        }
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        let normalizedProperty = property.lowercased()
        let isBackground = normalizedProperty.contains("background") || normalizedProperty == "bgcolor"

        if isBackground {
            // Darken white and near-white email canvases to the neutral range
            // used by system mail apps. Images retain their own pixels, so a
            // logo plate does not need the sender's white table background.
            if luminance > 0.78 { return "#242426" }
            if luminance > 0.52 { return "#3a3a3c" }
            return literal
        }

        // Sender-authored dark text is the common unreadable case in dark mode.
        if luminance < 0.25 { return "#f2f2f7" }
        if luminance < 0.50 { return "#d1d1d6" }
        return literal
    }

    private static func rgbaComponents(from literal: String) -> (Double, Double, Double, Double)? {
        let normalized = literal.lowercased()
        if normalized.hasPrefix("#") {
            let hex = String(normalized.dropFirst())
            let expanded: String
            switch hex.count {
            case 3: expanded = hex.map { "\($0)\($0)" }.joined() + "ff"
            case 4: expanded = hex.map { "\($0)\($0)" }.joined()
            case 6: expanded = hex + "ff"
            case 8: expanded = hex
            default: return nil
            }
            guard let value = UInt64(expanded, radix: 16) else { return nil }
            return (
                Double((value >> 24) & 0xff) / 255,
                Double((value >> 16) & 0xff) / 255,
                Double((value >> 8) & 0xff) / 255,
                Double(value & 0xff) / 255
            )
        }

        let numbers = normalized
            .replacingOccurrences(of: "rgba", with: "")
            .replacingOccurrences(of: "rgb", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count >= 3 else { return nil }
        return (
            min(max(numbers[0] / 255, 0), 1),
            min(max(numbers[1] / 255, 0), 1),
            min(max(numbers[2] / 255, 0), 1),
            numbers.count > 3 ? min(max(numbers[3], 0), 1) : 1
        )
    }

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
