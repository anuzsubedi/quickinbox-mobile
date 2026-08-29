package dev.anuz.quickinbox.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext

@Composable
fun QuickInboxTheme(content: @Composable () -> Unit) {
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

/** Always-dark scheme used by full-screen camera surfaces. */
@Composable
fun rememberScannerColorScheme(): ColorScheme {
    val context = LocalContext.current
    return remember(context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) dynamicDarkColorScheme(context)
        else darkColorScheme(primary = Color(0xFF8DDBAD))
    }
}

private fun ColorScheme.withLiftedCanvas(): ColorScheme {
    val canvas = darkCanvas()
    return copy(background = canvas, surface = canvas)
}

private fun ColorScheme.darkCanvas(): Color {
    val base = surfaceContainerLow
    return if (base.luminance() < 0.04f) lerp(base, primary, 0.14f) else base
}
