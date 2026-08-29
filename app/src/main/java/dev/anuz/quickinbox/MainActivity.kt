package dev.anuz.quickinbox

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Dns
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.QrCodeScanner
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import org.json.JSONObject
import java.util.concurrent.Executors

private val Green = Color(0xFF195C3B)
private val PaleGreen = Color(0xFFDDEFE3)
private val Canvas = Color(0xFFF8FAF7)
private val Ink = Color(0xFF17211B)
private val Muted = Color(0xFF5C6B62)
private const val PrivacyUrl = "https://quickinbox.quivren.com/privacy"

private val FallbackLight = lightColorScheme(
    primary = Green,
    onPrimary = Color.White,
    primaryContainer = PaleGreen,
    onPrimaryContainer = Green,
    secondary = Green,
    onSecondary = Color.White,
    secondaryContainer = PaleGreen,
    onSecondaryContainer = Green,
    background = Canvas,
    surface = Canvas,
    surfaceContainer = Color.White,
    onSurface = Ink,
    onSurfaceVariant = Muted,
    outline = Color(0xFFBCC8C0),
    error = Color(0xFFB3261E)
)

private val FallbackDark = darkColorScheme(
    primary = Color(0xFF8DDBAD),
    onPrimary = Color(0xFF003822),
    primaryContainer = Color(0xFF1A3D2C),
    onPrimaryContainer = Color(0xFFA8E8C4),
    secondary = Color(0xFF8DDBAD),
    onSecondary = Color(0xFF003822),
    secondaryContainer = Color(0xFF1A3D2C),
    onSecondaryContainer = PaleGreen,
    background = Color(0xFF1C221E),
    surface = Color(0xFF1C221E),
    surfaceContainer = Color(0xFF262C28),
    onSurface = Color(0xFFE6EDE7),
    onSurfaceVariant = Color(0xFFA8B5AD),
    outline = Color(0xFF4A5850),
    error = Color(0xFFF2B8B5)
)

private val BricolageGrotesque = FontFamily(
    Font(R.font.bricolage_grotesque_medium, FontWeight(560)),
    Font(R.font.bricolage_grotesque_semibold, FontWeight(620))
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { QuickInboxTheme { QuickInboxApp() } }
    }
}

private enum class Screen { Onboarding, Scanner, Privacy }
private data class Pairing(val origin: String, val code: String)

@Composable
private fun QuickInboxTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val colorScheme = remember(dark, context) {
        val scheme = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        } else if (dark) FallbackDark else FallbackLight
        if (dark) scheme.withLiftedCanvas() else scheme
    }
    MaterialTheme(colorScheme = colorScheme, content = content)
}

private fun ColorScheme.withLiftedCanvas(): ColorScheme {
    val canvas = darkCanvas()
    return copy(background = canvas, surface = canvas)
}

private fun ColorScheme.darkCanvas(): Color {
    val base = surfaceContainerLow
    return if (base.luminance() < 0.04f) lerp(base, primary, 0.14f) else base
}

@Composable
private fun QuickInboxApp() {
    var screen by remember { mutableStateOf(Screen.Onboarding) }
    var showManual by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var scanned by remember { mutableStateOf<Pairing?>(null) }
    var server by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }

    when (screen) {
            Screen.Onboarding -> OnboardingScreen(
                error = error,
                onScan = { error = null; screen = Screen.Scanner },
                onManual = { error = null; showManual = true },
                onPrivacy = { screen = Screen.Privacy }
            )
            Screen.Scanner -> ScannerScreen(
                onBack = { screen = Screen.Onboarding },
                onManual = { screen = Screen.Onboarding; showManual = true },
                onScanned = { value ->
                    val result = validatePayload(value)
                    if (result == null) error = "Invalid pairing code"
                    else {
                        scanned = result
                        error = null
                        screen = Screen.Onboarding
                    }
                }
            )
            Screen.Privacy -> PrivacyScreen(onBack = { screen = Screen.Onboarding })
        }

        if (showManual) {
            ManualPairingSheet(
                server = server,
                code = code,
                error = error,
                onServerChange = { server = it; error = null },
                onCodeChange = { code = it; error = null },
                onDismiss = { showManual = false },
                onConnect = {
                    val result = validatePairing(server, code)
                    if (result == null) error = "Check the server and pairing code"
                    else {
                        scanned = result
                        error = null
                        showManual = false
                    }
                }
            )
        }

        scanned?.let { pairing ->
            AlertDialog(
                onDismissRequest = { scanned = null },
                icon = { Icon(Icons.Rounded.Lock, contentDescription = null) },
                title = { Text("Confirm server") },
                text = { Text(Uri.parse(pairing.origin).host ?: pairing.origin) },
                confirmButton = { Button(onClick = { scanned = null }) { Text("Connect") } },
                dismissButton = { TextButton(onClick = { scanned = null }) { Text("Cancel") } }
            )
        }
}

@Composable
private fun OnboardingScreen(error: String?, onScan: () -> Unit, onManual: () -> Unit, onPrivacy: () -> Unit) {
    Scaffold(containerColor = MaterialTheme.colorScheme.background) { contentPadding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(contentPadding).padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth().height(32.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                androidx.compose.foundation.Image(
                    painter = painterResource(R.drawable.ic_quickinbox),
                    contentDescription = null,
                    modifier = Modifier.size(32.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    "QuickInbox",
                    style = TextStyle(
                        fontFamily = BricolageGrotesque,
                        fontWeight = FontWeight(620),
                        fontSize = 16.sp,
                        letterSpacing = (-0.03).em,
                        lineHeight = 16.sp,
                        platformStyle = PlatformTextStyle(includeFontPadding = false),
                        lineHeightStyle = LineHeightStyle(
                            alignment = LineHeightStyle.Alignment.Center,
                            trim = LineHeightStyle.Trim.Both
                        )
                    )
                )
            }
            Column(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                androidx.compose.foundation.Image(
                    painter = painterResource(R.drawable.onboarding_inbox_mark),
                    contentDescription = null,
                    modifier = Modifier.fillMaxWidth().aspectRatio(3f / 2f),
                    contentScale = ContentScale.Fit
                )
                Spacer(Modifier.height(22.dp))
                Text(
                    "Connect to your\nprivate server",
                    fontFamily = BricolageGrotesque,
                    fontWeight = FontWeight(560),
                    fontSize = 34.sp,
                    lineHeight = (34 * 1.04).sp,
                    letterSpacing = (-0.035).em,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(10.dp))
                Text(
                    "Connect securely to continue",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
            error?.let {
                Surface(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.errorContainer) {
                    Text(it, modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                }
                Spacer(Modifier.height(12.dp))
            }
            Button(onClick = onScan, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(16.dp)) {
                Icon(Icons.Rounded.QrCodeScanner, contentDescription = null)
                Spacer(Modifier.width(10.dp))
                Text("Scan QR code", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(10.dp))
            FilledTonalButton(
                onClick = onManual,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                Icon(Icons.Rounded.Keyboard, contentDescription = null)
                Spacer(Modifier.width(10.dp))
                Text("Enter code")
            }
            Spacer(Modifier.height(16.dp))
            PrivacyAgreement(onPrivacy)
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun PrivacyAgreement(onPrivacy: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val text = buildAnnotatedString {
        append("By continuing you agree to the ")
        withLink(
            LinkAnnotation.Clickable(
                tag = "privacy",
                styles = TextLinkStyles(
                    style = SpanStyle(color = colors.primary, fontWeight = FontWeight.Medium)
                ),
                linkInteractionListener = { onPrivacy() }
            )
        ) {
            append("privacy policy")
        }
    }
    Text(
        text = text,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
        color = colors.onSurfaceVariant,
        style = MaterialTheme.typography.bodySmall,
        textAlign = TextAlign.Center
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PrivacyScreen(onBack: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val dark = isSystemInDarkTheme()
    var loading by remember { mutableStateOf(true) }
    var webView by remember { mutableStateOf<WebView?>(null) }

    BackHandler {
        val current = webView
        if (current?.canGoBack() == true) current.goBack() else onBack()
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("Privacy policy", fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onSurface,
                    navigationIconContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    ) { contentPadding ->
        Box(Modifier.fillMaxSize().padding(contentPadding)) {
            key(dark) {
            AndroidView(
                factory = { context ->
                    WebView(context).apply {
                        settings.javaScriptEnabled = true
                        settings.domStorageEnabled = true
                        if (dark) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                settings.isAlgorithmicDarkeningAllowed = true
                            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                @Suppress("DEPRECATION")
                                settings.forceDark = WebSettings.FORCE_DARK_ON
                            }
                        }
                        webViewClient = object : WebViewClient() {
                            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                                val scheme = request.url.scheme
                                return scheme != "https" && scheme != "http"
                            }
                        }
                        webChromeClient = object : WebChromeClient() {
                            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                                loading = newProgress < 100
                            }
                        }
                        loadUrl(PrivacyUrl)
                        webView = this
                    }
                },
                modifier = Modifier.fillMaxSize()
            )
            }
            if (loading) {
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth().align(Alignment.TopCenter),
                    color = colors.primary,
                    trackColor = colors.primaryContainer
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ManualPairingSheet(
    server: String,
    code: String,
    error: String?,
    onServerChange: (String) -> Unit,
    onCodeChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onConnect: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().imePadding().padding(horizontal = 24.dp)
                .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 24.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Connect manually", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
                    Text("Enter the details from your server", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                IconButton(onClick = onDismiss) { Icon(Icons.Rounded.Close, contentDescription = "Close") }
            }
            Spacer(Modifier.height(24.dp))
            OutlinedTextField(
                value = server,
                onValueChange = onServerChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Server address") },
                placeholder = { Text("https://mail.example.com") },
                leadingIcon = { Icon(Icons.Rounded.Dns, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(16.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)
            )
            Spacer(Modifier.height(14.dp))
            OutlinedTextField(
                value = code,
                onValueChange = { onCodeChange(it.take(22)) },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Pairing code") },
                supportingText = { Text("${code.length}/22") },
                leadingIcon = { Icon(Icons.Rounded.Key, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(16.dp),
                textStyle = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Monospace),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii)
            )
            error?.let {
                Text(it, modifier = Modifier.padding(top = 10.dp, start = 4.dp), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = onConnect,
                enabled = server.isNotBlank() && code.length == 22,
                modifier = Modifier.fillMaxWidth().height(56.dp),
                shape = RoundedCornerShape(18.dp)
            ) { Text("Connect", fontWeight = FontWeight.SemiBold) }
        }
    }
}

@Composable
private fun ScannerScreen(onBack: () -> Unit, onManual: () -> Unit, onScanned: (String) -> Unit) {
    val context = LocalContext.current
    var permission by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { permission = it }
    LaunchedEffect(Unit) { if (!permission) launcher.launch(Manifest.permission.CAMERA) }

    val scannerColors = remember(context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) dynamicDarkColorScheme(context)
        else darkColorScheme(primary = Color(0xFF8DDBAD))
    }
    MaterialTheme(colorScheme = scannerColors) {
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            if (permission) CameraPreview(onScanned = onScanned, modifier = Modifier.fillMaxSize())
            else ScannerStatus {
                context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
            }
            Row(
                modifier = Modifier.fillMaxWidth()
                    .padding(top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 8.dp)
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(shape = CircleShape, color = Color.Black.copy(alpha = 0.45f)) {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back", tint = Color.White) }
                }
                Spacer(Modifier.weight(1f))
                Text(
                    "Scan code",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.background(Color.Black.copy(alpha = 0.45f), CircleShape).padding(horizontal = 16.dp, vertical = 10.dp)
                )
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.size(48.dp))
            }
            OutlinedButton(
                onClick = onManual,
                modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(horizontal = 24.dp)
                    .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 20.dp).height(54.dp),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.outlinedButtonColors(containerColor = Color.Black.copy(alpha = 0.55f), contentColor = Color.White),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color.White.copy(alpha = 0.45f))
            ) {
                Icon(Icons.Rounded.Keyboard, contentDescription = null)
                Spacer(Modifier.width(10.dp))
                Text("Enter code")
            }
        }
    }
}

@Composable
private fun ScannerStatus(onSettings: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Surface(modifier = Modifier.size(88.dp), shape = CircleShape, color = Color.White.copy(alpha = 0.1f)) {
            Box(contentAlignment = Alignment.Center) { Icon(Icons.Rounded.CameraAlt, contentDescription = null, modifier = Modifier.size(36.dp)) }
        }
        Spacer(Modifier.height(20.dp))
        Text("Camera access needed", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        Text("Enable camera access to scan", color = Color.White.copy(alpha = 0.7f))
        Spacer(Modifier.height(20.dp))
        Button(onClick = onSettings) { Text("Open settings") }
    }
}

@Composable
private fun CameraPreview(onScanned: (String) -> Unit, modifier: Modifier) {
    val context = LocalContext.current
    var handled by remember { mutableStateOf(false) }
    AndroidView(
        factory = { contextView ->
            PreviewView(contextView).also { view ->
                view.scaleType = PreviewView.ScaleType.FILL_CENTER
                val providerFuture = ProcessCameraProvider.getInstance(context)
                providerFuture.addListener({
                    val cameraProvider = providerFuture.get()
                    val preview = Preview.Builder().build().also { it.setSurfaceProvider(view.surfaceProvider) }
                    val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                    val executor = Executors.newSingleThreadExecutor()
                    analysis.setAnalyzer(executor) { proxy ->
                        proxy.image?.let { mediaImage ->
                            BarcodeScanning.getClient().process(InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees))
                                .addOnSuccessListener { codes ->
                                    if (!handled) codes.firstOrNull()?.rawValue?.let { handled = true; onScanned(it) }
                                }
                                .addOnCompleteListener { proxy.close() }
                        } ?: proxy.close()
                    }
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(context as ComponentActivity, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                }, ContextCompat.getMainExecutor(context))
            }
        },
        modifier = modifier
    )
    Box(modifier, contentAlignment = Alignment.Center) {
        Box(Modifier.size(278.dp).border(3.dp, Color.White, RoundedCornerShape(30.dp)))
    }
}

private fun validatePayload(value: String): Pairing? = try {
    val json = JSONObject(value)
    if (json.length() != 3 || json.optInt("version") != 1) null
    else validatePairing(json.getString("origin"), json.getString("code"))
} catch (_: Exception) { null }

private fun validatePairing(origin: String, code: String): Pairing? {
    val uri = Uri.parse(origin.trim())
    val clean = code.trim()
    return if (
        (uri.scheme == "https" || uri.scheme == "http") && !uri.host.isNullOrBlank() &&
        clean.length == 22 && clean.all { it.isLetterOrDigit() || it == '_' || it == '-' }
    ) Pairing(uri.toString(), clean) else null
}
