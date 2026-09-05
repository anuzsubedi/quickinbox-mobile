package dev.anuz.quickinbox.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

val LocalQuickInboxDarkTheme = staticCompositionLocalOf { false }

@Composable
fun QuickInboxTheme(
    themeId: String = DEFAULT_APP_THEME_ID,
    content: @Composable () -> Unit
) {
    val option = AppThemeOption.fromId(themeId)
    val dark = option.forcedDark ?: isSystemInDarkTheme()
    val colorScheme = rememberAppColorScheme(option, dark)
    CompositionLocalProvider(LocalQuickInboxDarkTheme provides dark) {
        MaterialExpressiveTheme(
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

/** Shared by the live app and the Appearance previews. */
@Composable
internal fun rememberAppColorScheme(option: AppThemeOption, dark: Boolean): ColorScheme {
    val context = LocalContext.current
    val effectiveDark = option.forcedDark ?: dark
    return remember(option, effectiveDark, context) {
        if (option == AppThemeOption.Monet && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val dynamic = if (effectiveDark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
            dynamic.withBalancedSurfaces(effectiveDark)
        } else {
            option.materialScheme(effectiveDark)
        }
    }
}
