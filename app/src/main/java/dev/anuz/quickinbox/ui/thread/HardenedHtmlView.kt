package dev.anuz.quickinbox.ui.thread

import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.view.View
import android.webkit.CookieManager
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import dev.anuz.quickinbox.ui.theme.LocalQuickInboxDarkTheme
import java.io.ByteArrayInputStream
import kotlin.math.ceil

@Composable
internal fun HardenedHtmlView(html: String, loadsRemoteImages: Boolean) {
    val dark = LocalQuickInboxDarkTheme.current
    val scheme = MaterialTheme.colorScheme
    val sheet = if (dark) scheme.surfaceContainerLow else scheme.surfaceContainerLowest
    val chrome = remember(scheme, dark, sheet) {
        HtmlChromeColors(
            canvas = sheet.toCssHex(),
            raised = scheme.surfaceContainerHigh.toCssHex(),
            text = scheme.onSurface.toCssHex(),
            secondary = scheme.onSurfaceVariant.toCssHex(),
            link = scheme.primary.toCssHex()
        )
    }
    val canvasArgb = sheet.toArgb()
    val document = remember(html, loadsRemoteImages, dark, chrome) {
        HtmlMessageSanitizer.document(html, loadsRemoteImages, dark, chrome)
    }
    var heightDpValue by remember { mutableIntStateOf(44) }
    var rendererEpoch by remember { mutableIntStateOf(0) }
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val session = remember { MessageWebSession() }

    LaunchedEffect(document) {
        heightDpValue = 44
    }
    session.allowRemoteImages = loadsRemoteImages

    fun measure(view: WebView) {
        if (view.width <= 0) {
            view.post { measure(view) }
            return
        }
        val viewDp = view.width / density
        view.evaluateJavascript("($FIT_AND_MEASURE)()") { raw ->
            val values = raw.trim('"').split(',')
            val cssHeight = values.getOrNull(0)?.toDoubleOrNull() ?: return@evaluateJavascript
            val contentWidth = values.getOrNull(1)?.toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 }
                ?: return@evaluateJavascript
            heightDpValue = ceil(cssHeight * viewDp / contentWidth).toInt().coerceAtLeast(44)
        }
    }

    key(rendererEpoch) {
        AndroidView(
            factory = { viewContext ->
                MessageWebView(viewContext).apply {
                    setBackgroundColor(canvasArgb)
                    overScrollMode = View.OVER_SCROLL_NEVER
                    isNestedScrollingEnabled = false
                    isVerticalScrollBarEnabled = false
                    isHorizontalScrollBarEnabled = false
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = false
                    settings.allowFileAccess = false
                    settings.allowContentAccess = false
                    settings.cacheMode = WebSettings.LOAD_NO_CACHE
                    settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                    settings.mediaPlaybackRequiresUserGesture = true
                    settings.javaScriptCanOpenWindowsAutomatically = false
                    settings.setSupportMultipleWindows(false)
                    settings.useWideViewPort = true
                    settings.loadWithOverviewMode = true
                    settings.textZoom = 100
                    settings.layoutAlgorithm = WebSettings.LayoutAlgorithm.NORMAL
                    settings.setSupportZoom(true)
                    settings.builtInZoomControls = true
                    settings.displayZoomControls = false
                    settings.blockNetworkImage = !loadsRemoteImages
                    CookieManager.getInstance().setAcceptThirdPartyCookies(this, false)
                    webChromeClient = object : WebChromeClient() {
                        override fun onCreateWindow(
                            view: WebView?,
                            isDialog: Boolean,
                            isUserGesture: Boolean,
                            resultMsg: android.os.Message?
                        ): Boolean = false
                    }
                    webViewClient = object : WebViewClient() {
                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                            openExternalUrl(context, request.url.scheme, request.url)
                            return true
                        }

                        override fun shouldInterceptRequest(
                            view: WebView,
                            request: WebResourceRequest
                        ): WebResourceResponse? {
                            if (request.isForMainFrame) return null
                            val scheme = request.url.scheme
                            if (scheme.isNullOrEmpty() || allowedRequest(scheme, session.allowRemoteImages)) return null
                            return blockedResponse()
                        }

                        override fun onPageFinished(view: WebView, url: String?) {
                            measure(view)
                            view.postDelayed({ measure(view) }, 80)
                            view.postDelayed({ measure(view) }, 300)
                            view.postDelayed({ measure(view) }, 900)
                        }

                        override fun onLoadResource(view: WebView, url: String?) {
                            view.postDelayed({ measure(view) }, 40)
                        }

                        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                            view.post { rendererEpoch += 1 }
                            return true
                        }
                    }
                }
            },
            update = { view ->
                view.setBackgroundColor(canvasArgb)
                view.settings.blockNetworkImage = !loadsRemoteImages
                if (view.loadedDocument != document) {
                    view.loadedDocument = document
                    view.loadDataWithBaseURL(DOCUMENT_BASE, document, "text/html", "utf-8", null)
                }
            },
            onRelease = { view ->
                view.stopLoading()
                view.webChromeClient = null
                view.webViewClient = WebViewClient()
                view.loadUrl("about:blank")
                view.clearHistory()
                view.clearCache(true)
                view.clearFormData()
                view.destroy()
            },
            modifier = Modifier.fillMaxWidth().height(heightDpValue.dp)
        )
    }
}

private class MessageWebSession {
    var allowRemoteImages: Boolean = false
}

@SuppressLint("ClickableViewAccessibility")
private class MessageWebView(context: Context) : WebView(context) {
    var loadedDocument: String? = null

    init {
        setOnTouchListener { view, event ->
            view.parent.requestDisallowInterceptTouchEvent(event.pointerCount > 1)
            false
        }
    }

    override fun overScrollBy(
        deltaX: Int,
        deltaY: Int,
        scrollX: Int,
        scrollY: Int,
        scrollRangeX: Int,
        scrollRangeY: Int,
        maxOverScrollX: Int,
        maxOverScrollY: Int,
        isTouchEvent: Boolean
    ): Boolean = super.overScrollBy(
        deltaX, 0, scrollX, 0, scrollRangeX, 0, maxOverScrollX, 0, isTouchEvent
    )

    override fun scrollTo(x: Int, y: Int) {
        super.scrollTo(x, 0)
    }
}

private const val DOCUMENT_BASE = "https://quickinbox.invalid/"

private val FIT_AND_MEASURE = """
    function() {
        const html = document.documentElement;
        const body = document.body;
        if (!body) return '44,1';
        body.style.zoom = '1';
        body.style.transform = 'none';
        html.style.zoom = '1';
        html.style.maxWidth = 'none';
        body.style.maxWidth = 'none';
        html.style.overflowX = 'visible';
        body.style.overflowX = 'visible';
        const tables = body.querySelectorAll('table');
        for (var i = 0; i < tables.length; i++) tables[i].style.maxWidth = 'none';
        const originLeft = body.getBoundingClientRect().left + window.scrollX;
        const originTop = body.getBoundingClientRect().top + window.scrollY;
        const marker = document.createElement('div');
        marker.style.cssText = 'display:block;width:0;height:0;padding:0;margin:0;clear:both;';
        body.appendChild(marker);
        var bottom = marker.getBoundingClientRect().bottom + window.scrollY;
        var right = 0;
        marker.remove();
        const elements = body.querySelectorAll('*');
        for (var i = 0; i < elements.length; i++) {
            const rect = elements[i].getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) {
                bottom = Math.max(bottom, rect.bottom + window.scrollY);
                right = Math.max(right, rect.right + window.scrollX);
            }
        }
        const images = document.images;
        for (var i = 0; i < images.length; i++) {
            right = Math.max(right, images[i].getBoundingClientRect().right + window.scrollX);
        }
        const viewport = Math.max(window.innerWidth, html.clientWidth, 1);
        const contentWidth = Math.max(right - originLeft, body.scrollWidth, html.scrollWidth, viewport);
        const height = Math.max(44, bottom - originTop);
        const scale = contentWidth > viewport + 2 ? (viewport / contentWidth) : 1;
        body.style.transformOrigin = '0 0';
        body.style.zoom = String(scale);
        var fitted = body.getBoundingClientRect().width;
        if (scale < 1 && fitted > viewport + 4) {
            body.style.zoom = '1';
            body.style.transform = 'scale(' + scale + ')';
        }
        html.style.overflowX = 'hidden';
        body.style.overflowX = 'hidden';
        return height + ',' + contentWidth;
    }
""".trimIndent()

private fun allowedRequest(scheme: String?, allowRemoteImages: Boolean): Boolean {
    return when (scheme?.lowercase()) {
        "data", "about" -> true
        "http", "https" -> allowRemoteImages
        else -> false
    }
}

private fun blockedResponse(): WebResourceResponse =
    WebResourceResponse("text/plain", "utf-8", 403, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0)))

private fun Color.toCssHex(): String {
    val r = (red * 255f + 0.5f).toInt().coerceIn(0, 255)
    val g = (green * 255f + 0.5f).toInt().coerceIn(0, 255)
    val b = (blue * 255f + 0.5f).toInt().coerceIn(0, 255)
    return "#%02X%02X%02X".format(r, g, b)
}

private fun openExternalUrl(context: Context, scheme: String?, uri: android.net.Uri) {
    if (scheme !in setOf("http", "https", "mailto", "tel")) return
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
    } catch (_: ActivityNotFoundException) {
    }
}
