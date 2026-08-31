package dev.anuz.quickinbox.ui.scanner

import androidx.activity.ComponentActivity
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors

/** Paper theme cobalt, lifted for the always-dark camera surface. */
private val ScannerCobalt = Color(0xFFA7B4F5)

@Composable
@OptIn(markerClass = [ExperimentalGetImage::class])
fun CameraPreview(onScanned: (String) -> Unit, modifier: Modifier) {
    val context = LocalContext.current
    var handled by remember { mutableStateOf(false) }
    val providerFuture = remember(context) { ProcessCameraProvider.getInstance(context) }
    val executor = remember { Executors.newSingleThreadExecutor() }
    val scanner = remember { BarcodeScanning.getClient() }

    DisposableEffect(providerFuture, executor, scanner) {
        onDispose {
            if (providerFuture.isDone) providerFuture.get().unbindAll()
            scanner.close()
            executor.shutdown()
        }
    }

    AndroidView(
        factory = { contextView ->
            PreviewView(contextView).also { view ->
                view.scaleType = PreviewView.ScaleType.FILL_CENTER
                providerFuture.addListener({
                    if (executor.isShutdown) return@addListener
                    val cameraProvider = providerFuture.get()
                    val preview = Preview.Builder().build().also { it.setSurfaceProvider(view.surfaceProvider) }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                    analysis.setAnalyzer(executor) { proxy ->
                        proxy.image?.let { mediaImage ->
                            scanner.process(InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees))
                                .addOnSuccessListener { codes ->
                                    if (!handled) codes.firstOrNull()?.rawValue?.let {
                                        handled = true
                                        onScanned(it)
                                    }
                                }
                                .addOnCompleteListener { proxy.close() }
                        } ?: proxy.close()
                    }
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        context as ComponentActivity,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        analysis
                    )
                }, ContextCompat.getMainExecutor(context))
            }
        },
        modifier = modifier
    )
    Box(modifier, contentAlignment = Alignment.Center) {
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
