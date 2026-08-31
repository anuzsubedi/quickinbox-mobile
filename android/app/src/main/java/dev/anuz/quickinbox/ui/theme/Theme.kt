package dev.anuz.quickinbox.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext

val LocalQuickInboxDarkTheme = staticCompositionLocalOf { false }

@Composable
fun QuickInboxTheme(
    themeId: String = DEFAULT_APP_THEME_ID,
    content: @Composable () -> Unit
) {
    val option = AppThemeOption.fromId(themeId)
    val dark = option.forcedDark ?: isSystemInDarkTheme()
    val context = LocalContext.current
    val colorScheme = remember(option, dark, context) {
        if (option == AppThemeOption.Monet && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val dynamic = if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
            if (dark) dynamic.withLiftedCanvas() else dynamic
        } else {
            option.materialScheme(dark)
        }
    }
    CompositionLocalProvider(LocalQuickInboxDarkTheme provides dark) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = QuickInboxTypography,
            content = content
        )
    }
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
