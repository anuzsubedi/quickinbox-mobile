import SwiftUI
import WebKit

/// Displays email HTML in an ephemeral, noninteractive WebKit surface.
///
/// JavaScript, cookies, forms, frames, remote resources, and navigation are disabled.
/// The HTML is still treated as untrusted even though the server also sanitizes mail.
struct HardenedHTMLView: View {
    let html: String
    @State private var contentHeight: CGFloat = 120

    var body: some View {
        HardenedWebView(html: HTMLMessageSanitizer.document(from: html), height: $contentHeight)
            .frame(height: max(44, contentHeight))
            .accessibilityLabel("Formatted email message")
    }
}

private struct HardenedWebView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
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
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        // Selection and native <details> disclosure remain available. Link and
        // window navigation is independently denied by the navigation delegates.
        webView.isUserInteractionEnabled = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
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

        init(height: Binding<CGFloat>) {
            _height = height
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
            decisionHandler(isInitialDocument ? .allow : .cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            nil
        }
    }
}

nonisolated enum HTMLMessageSanitizer {
    static func document(from rawHTML: String) -> String {
        var body = rawHTML

        // Remove active and document-level elements before the content reaches WebKit.
        let blockedElements = ["script", "style", "iframe", "frame", "object", "embed", "form", "button", "input", "textarea", "select", "meta", "base", "link"]
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
        body = replacing(#"\s+(?:href|src|poster|action)\s*=\s*(?:\"|')?\s*(?:javascript|file|http|https):[^\s>]*(?:\"|')?"#, in: body, with: "")
        body = replacing(#"url\s*\([^)]*\)"#, in: body, with: "none")

        // Native HTML disclosure works with JavaScript disabled and keeps quoted mail out of the way.
        body = replacing(#"<blockquote\b([^>]*)>"#, in: body, with: "<details><summary>Show quoted history</summary><blockquote$1>")
        body = replacing(#"</blockquote\s*>"#, in: body, with: "</blockquote></details>")

        return """
        <!doctype html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src 'none'; media-src 'none'; frame-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'">
        <style>
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; background: transparent; color: -apple-system-label; }
        body { font: -apple-system-body; overflow-wrap: anywhere; line-height: 1.38; }
        img { max-width: 100%; height: auto; }
        a { color: -apple-system-link; text-decoration: underline; }
        pre { white-space: pre-wrap; }
        blockquote { margin: .6em 0 0 .55em; padding-left: .75em; border-left: 2px solid -apple-system-quaternary-label; color: -apple-system-secondary-label; }
        details { margin-top: .75em; color: -apple-system-secondary-label; }
        summary { font-weight: 600; }
        table { max-width: 100%; border-collapse: collapse; }
        </style></head><body>\(body)</body></html>
        """
    }

    private static func replacing(_ pattern: String, in value: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return value
        }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}
