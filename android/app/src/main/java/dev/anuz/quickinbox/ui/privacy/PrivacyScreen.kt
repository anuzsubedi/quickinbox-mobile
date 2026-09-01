package dev.anuz.quickinbox.ui.privacy

import android.content.Context
import android.net.Uri
import android.os.Build
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import dev.anuz.quickinbox.ui.theme.LocalQuickInboxDarkTheme

const val PRIVACY_URL = "https://quickinbox.quivren.com/privacy"

private const val PRIVACY_HOST = "quickinbox.quivren.com"
private const val PRIVACY_LOAD_ERROR =
    "We couldn't load the privacy policy. Check your connection and try again."
private const val PRIVACY_NAVIGATION_ERROR = "That privacy policy link was blocked."
private const val PRIVACY_RENDERER_ERROR = "The privacy policy stopped responding. Please try again."

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrivacyScreen(onBack: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val dark = LocalQuickInboxDarkTheme.current
    var loading by remember { mutableStateOf(true) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var webView by remember { mutableStateOf<WebView?>(null) }
    var webViewEpoch by remember { mutableIntStateOf(0) }

    val retry = {
        loading = true
        loadError = null
        webView = null
        webViewEpoch += 1
    }

    BackHandler {
        val current = webView
        if (current?.canGoBack() == true) current.goBack() else onBack()
    }

    Scaffold(
        containerColor = colors.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Privacy policy",
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.semantics { heading() }
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = colors.background,
                    titleContentColor = colors.onSurface,
                    navigationIconContentColor = colors.onSurface
                )
            )
        }
    ) { contentPadding ->
        Box(Modifier.fillMaxSize().padding(contentPadding)) {
            if (loadError == null) {
                key(dark, webViewEpoch) {
                    AndroidView(
                        factory = { context ->
                            PrivacyWebView(context).apply {
                                webView = this
                                loading = true
                                configure(
                                    dark = dark,
                                    onLoading = { view ->
                                        if (webView === view) loading = true
                                    },
                                    onLoaded = { view ->
                                        if (webView === view) loading = false
                                    },
                                    onLoadError = { view, message ->
                                        if (webView === view) {
                                            loading = false
                                            loadError = message
                                        }
                                    },
                                    onRendererGone = { view ->
                                        if (webView === view) {
                                            webView = null
                                            loading = false
                                            loadError = PRIVACY_RENDERER_ERROR
                                        }
                                    }
                                )
                                loadUrl(PRIVACY_URL)
                            }
                        },
                        onRelease = { view ->
                            if (webView === view) webView = null
                            view.release()
                        },
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
            if (loading && loadError == null) {
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth().align(Alignment.TopCenter)
                        .semantics { contentDescription = "Loading privacy policy" },
                    color = colors.primary,
                    trackColor = colors.primaryContainer
                )
            }
            loadError?.let { message ->
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = colors.background
                ) {
                    Box(
                        modifier = Modifier.fillMaxSize().padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Surface(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(24.dp),
                            color = colors.surfaceContainerLow,
                            tonalElevation = 1.dp
                        ) {
                            Column(
                                modifier = Modifier.padding(horizontal = 24.dp, vertical = 28.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    "Privacy policy unavailable",
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.SemiBold,
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier.semantics { heading() }
                                )
                                Text(
                                    message,
                                    modifier = Modifier.padding(top = 10.dp),
                                    color = colors.onSurfaceVariant,
                                    style = MaterialTheme.typography.bodyMedium,
                                    textAlign = TextAlign.Center
                                )
                                Button(
                                    onClick = retry,
                                    modifier = Modifier.padding(top = 24.dp).height(52.dp),
                                    shape = RoundedCornerShape(18.dp)
                                ) {
                                    Text("Try again", fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun WebView.configure(
    dark: Boolean,
    onLoading: (WebView) -> Unit,
    onLoaded: (WebView) -> Unit,
    onLoadError: (WebView, String) -> Unit,
    onRendererGone: (WebView) -> Unit
) {
    settings.javaScriptEnabled = true
    settings.domStorageEnabled = true
    settings.allowFileAccess = false
    settings.allowContentAccess = false
    settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
    settings.javaScriptCanOpenWindowsAutomatically = false
    settings.setSupportMultipleWindows(false)
    if (dark) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            settings.isAlgorithmicDarkeningAllowed = true
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            settings.forceDark = WebSettings.FORCE_DARK_ON
        }
    }
    var mainFrameFailed = false
    webChromeClient = object : WebChromeClient() {
        override fun onProgressChanged(view: WebView?, newProgress: Int) {
            if (view != null && newProgress < 100 && !mainFrameFailed) onLoading(view)
        }

        override fun onCreateWindow(
            view: WebView?,
            isDialog: Boolean,
            isUserGesture: Boolean,
            resultMsg: android.os.Message?
        ): Boolean = false
    }
    webViewClient = object : WebViewClient() {
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            return !isAllowedPrivacyUrl(request.url)
        }

        @Suppress("DEPRECATION")
        override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
            return !isAllowedPrivacyUrl(Uri.parse(url))
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
            val uri = url?.let(Uri::parse)
            if (uri == null || !isAllowedPrivacyUrl(uri)) {
                mainFrameFailed = true
                view.stopLoading()
                onLoadError(view, PRIVACY_NAVIGATION_ERROR)
                return
            }
            mainFrameFailed = false
            onLoading(view)
        }

        override fun onPageFinished(view: WebView, url: String?) {
            val uri = url?.let(Uri::parse)
            if (uri == null || !isAllowedPrivacyUrl(uri)) {
                mainFrameFailed = true
                view.stopLoading()
                onLoadError(view, PRIVACY_NAVIGATION_ERROR)
            } else if (!mainFrameFailed) {
                onLoaded(view)
            }
        }

        override fun onReceivedError(
            view: WebView,
            request: WebResourceRequest,
            error: WebResourceError
        ) {
            if (request.isForMainFrame) {
                mainFrameFailed = true
                onLoadError(view, PRIVACY_LOAD_ERROR)
            }
        }

        override fun onReceivedHttpError(
            view: WebView,
            request: WebResourceRequest,
            errorResponse: WebResourceResponse
        ) {
            if (request.isForMainFrame && errorResponse.statusCode >= 400) {
                mainFrameFailed = true
                onLoadError(view, PRIVACY_LOAD_ERROR)
            }
        }

        override fun onReceivedSslError(
            view: WebView,
            handler: android.webkit.SslErrorHandler,
            error: android.net.http.SslError
        ) {
            handler.cancel()
            if (error.url == view.url) {
                mainFrameFailed = true
                onLoadError(view, PRIVACY_LOAD_ERROR)
            }
        }

        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
            (view as? PrivacyWebView)?.rendererGone = true
            onRendererGone(view)
            return true
        }
    }
}

private fun isAllowedPrivacyUrl(uri: Uri): Boolean =
    uri.scheme?.equals("https", ignoreCase = true) == true &&
        uri.host?.equals(PRIVACY_HOST, ignoreCase = true) == true &&
        (uri.port == -1 || uri.port == 443) &&
        uri.userInfo == null

private class PrivacyWebView(context: Context) : WebView(context) {
    var rendererGone: Boolean = false
}

private fun PrivacyWebView.release() {
    runCatching { stopLoading() }
    webChromeClient = null
    webViewClient = WebViewClient()
    if (!rendererGone) {
        runCatching { loadUrl("about:blank") }
    }
    runCatching { clearHistory() }
    runCatching { clearFormData() }
    runCatching { removeAllViews() }
    runCatching { destroy() }
}
