package dev.anuz.quickinbox.ui.scanner

import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** Paper theme cobalt, lifted for the always-dark camera surface. */
private val ScannerCobalt = Color(0xFFA7B4F5)

@Composable
@OptIn(markerClass = [ExperimentalGetImage::class])
fun CameraPreview(onScanned: (String) -> Unit, modifier: Modifier) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var retryAttempt by remember { mutableStateOf(0) }
    var cameraError by remember { mutableStateOf(false) }
    val onScannedReference = remember { AtomicReference(onScanned) }
    onScannedReference.set(onScanned)
    val previewView = remember(context) {
        PreviewView(context).apply {
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
    }

    DisposableEffect(context, lifecycleOwner, previewView, retryAttempt) {
        cameraError = false
        val executor = Executors.newSingleThreadExecutor()
        val scanner = BarcodeScanning.getClient()
        val session = CameraSession(
            executor = executor,
            scanner = scanner,
            onScanned = { value -> onScannedReference.get().invoke(value) }
        )
        val providerFuture = try {
            ProcessCameraProvider.getInstance(context)
        } catch (_: Exception) {
            null
        }

        if (providerFuture == null) {
            if (session.close()) cameraError = true
        } else {
            try {
                providerFuture.addListener({
                    if (session.isClosed) return@addListener
                    try {
                        val cameraProvider = providerFuture.get()
                        if (!session.isClosed) {
                            session.start(cameraProvider, previewView, lifecycleOwner)
                        }
                    } catch (_: Exception) {
                        if (session.close()) cameraError = true
                    }
                }, ContextCompat.getMainExecutor(context))
            } catch (_: Exception) {
                if (session.close()) cameraError = true
            }
        }

        onDispose {
            session.close()
        }
    }

    Box(modifier) {
        AndroidView(
            factory = { previewView },
            modifier = Modifier.fillMaxSize()
        )

        // Keep the camera active for scanning while presenting a clean black surface.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        )

        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (cameraError) {
                CameraErrorPrompt(onRetry = {
                    cameraError = false
                    retryAttempt++
                })
            } else {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    ScannerFrame(
                        modifier = Modifier.size(260.dp),
                        color = ScannerCobalt
                    )
                    Surface(
                        shape = RoundedCornerShape(50),
                        color = Color.Black.copy(alpha = 0.5f)
                    ) {
                        Text(
                            "Align the server QR code inside the frame",
                            color = Color.White,
                            style = MaterialTheme.typography.bodyMedium,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
                        )
                    }
                }
            }
        }
    }
}

private class CameraSession(
    private val executor: ExecutorService,
    private val scanner: BarcodeScanner,
    private val onScanned: (String) -> Unit
) {
    private val lock = Any()
    private val handled = AtomicBoolean(false)
    private val closed = AtomicBoolean(false)
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var analysis: ImageAnalysis? = null

    val isClosed: Boolean
        get() = closed.get()

    @OptIn(markerClass = [ExperimentalGetImage::class])
    fun start(provider: ProcessCameraProvider, previewView: PreviewView, lifecycleOwner: LifecycleOwner) {
        synchronized(lock) {
            if (closed.get()) return

            val newPreview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }
            val newAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            newAnalysis.setAnalyzer(executor, ::analyze)

            cameraProvider = provider
            preview = newPreview
            analysis = newAnalysis
            provider.unbindAll()
            provider.bindToLifecycle(
                lifecycleOwner,
                CameraSelector.DEFAULT_BACK_CAMERA,
                newPreview,
                newAnalysis
            )
        }
    }

    @OptIn(markerClass = [ExperimentalGetImage::class])
    private fun analyze(proxy: ImageProxy) {
        val proxyClosed = AtomicBoolean(false)
        fun closeProxy() {
            if (proxyClosed.compareAndSet(false, true)) proxy.close()
        }

        val task = synchronized(lock) {
            if (closed.get()) {
                null
            } else {
                val mediaImage = proxy.image
                if (mediaImage == null) {
                    null
                } else {
                    try {
                        scanner.process(InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees))
                    } catch (_: Exception) {
                        null
                    }
                }
            }
        }

        if (task == null) {
            closeProxy()
            return
        }

        try {
            task.addOnCompleteListener { closeProxy() }
                .addOnSuccessListener { codes ->
                    if (closed.get()) return@addOnSuccessListener
                    codes.firstOrNull()?.rawValue?.let { value ->
                        synchronized(lock) {
                            if (!closed.get() && handled.compareAndSet(false, true)) {
                                onScanned(value)
                            }
                        }
                    }
                }
        } catch (_: Exception) {
            closeProxy()
        }
    }

    fun close(): Boolean {
        synchronized(lock) {
            if (!closed.compareAndSet(false, true)) return false
            try {
                analysis?.clearAnalyzer()
            } catch (_: Exception) {
                // The analyzer may already be clearing itself during lifecycle teardown.
            }
            try {
                preview?.setSurfaceProvider(null)
            } catch (_: Exception) {
                // The preview may already be detached during lifecycle teardown.
            }
            try {
                cameraProvider?.unbindAll()
            } catch (_: Exception) {
                // The provider may already be shutting down with the lifecycle owner.
            }
            analysis = null
            preview = null
            cameraProvider = null
            try {
                scanner.close()
            } catch (_: Exception) {
                // Scanner cleanup is best effort once the session is closed.
            }
            executor.shutdownNow()
        }
        return true
    }
}

@Composable
private fun CameraErrorPrompt(onRetry: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = Color.Black.copy(alpha = 0.72f),
        modifier = Modifier.padding(horizontal = 32.dp)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                "Camera unavailable",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                "We couldn't start the camera. Check that it isn't being used by another app, then try again.",
                color = Color.White.copy(alpha = 0.75f),
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center
            )
            Button(
                onClick = onRetry,
                colors = ButtonDefaults.buttonColors(
                    containerColor = ScannerCobalt,
                    contentColor = Color.Black
                ),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Try again")
            }
        }
    }
}

/**
 * Restrained cobalt corner brackets framing the scan area. Only the four corners are drawn so
 * the camera feed stays readable and the treatment never competes with the QR code.
 */
@Composable
private fun ScannerFrame(modifier: Modifier = Modifier, color: Color) {
    Canvas(modifier) {
        val stroke = 4.dp.toPx()
        val arm = 34.dp.toPx()
        val radius = 14.dp.toPx()
        val width = size.width
        val height = size.height
        val style = Stroke(width = stroke, cap = StrokeCap.Round, join = StrokeJoin.Round)

        fun bracket(path: Path.() -> Unit) {
            drawPath(Path().apply(path), color = color, style = style)
        }

        // Top-left
        bracket {
            moveTo(0f, arm)
            lineTo(0f, radius)
            arcTo(Rect(0f, 0f, radius * 2, radius * 2), 180f, 90f, false)
            lineTo(arm, 0f)
        }
        // Top-right
        bracket {
            moveTo(width - arm, 0f)
            lineTo(width - radius, 0f)
            arcTo(Rect(width - radius * 2, 0f, width, radius * 2), 270f, 90f, false)
            lineTo(width, arm)
        }
        // Bottom-right
        bracket {
            moveTo(width, height - arm)
            lineTo(width, height - radius)
            arcTo(Rect(width - radius * 2, height - radius * 2, width, height), 0f, 90f, false)
            lineTo(width - arm, height)
        }
        // Bottom-left
        bracket {
            moveTo(arm, height)
            lineTo(radius, height)
            arcTo(Rect(0f, height - radius * 2, radius * 2, height), 90f, 90f, false)
            lineTo(0f, height - arm)
        }
    }
}
