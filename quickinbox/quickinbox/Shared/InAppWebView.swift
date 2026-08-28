import SwiftUI
import WebKit

/// Displays a trusted QuickInbox web page inside the app.
struct InAppWebView: View {
    @Environment(\.colorScheme) private var colorScheme
    let url: URL

    var body: some View {
        InAppWebKitView(url: url, colorScheme: colorScheme)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct InAppWebKitView: UIViewRepresentable {
    let url: URL
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
    }
}
