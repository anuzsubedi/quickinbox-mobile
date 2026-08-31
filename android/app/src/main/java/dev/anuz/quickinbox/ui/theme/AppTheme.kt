package dev.anuz.quickinbox.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp

/**
 * The fresh-install default theme. `paper` is the stable id of the signature
 * "Paper" scheme, so existing users who already selected it keep working.
 */
const val DEFAULT_APP_THEME_ID = "paper"

enum class AppThemeOption(
    val id: String,
    val title: String,
    val detail: String,
    val forcedDark: Boolean? = null
) {
    Monet("monet", "Monet", "Material You colors from your wallpaper"),
    FoldedSignal("paper", "Paper", "Warm paper and cobalt, sage, and clay accents"),
    Porcelain("pureWhite", "Porcelain", "A crisp, gallery-white canvas", false),
    Midnight("amoledBlack", "Midnight", "True black with luminous details", true),
    SilverMist("mist", "Silver Mist", "Cool, quiet surfaces that follow the system"),
    SoftClay("clay", "Soft Clay", "Muted mineral warmth without losing contrast");

    companion object {
        fun fromId(id: String): AppThemeOption = entries.firstOrNull { it.id == id } ?: FoldedSignal
    }
}

internal fun AppThemeOption.materialScheme(dark: Boolean): ColorScheme = when (this) {
    AppThemeOption.Monet -> if (dark) FallbackDark else FallbackLight
    AppThemeOption.FoldedSignal -> if (dark) foldedSignalDark else foldedSignalLight
    AppThemeOption.Porcelain -> porcelain
    AppThemeOption.Midnight -> midnight
    AppThemeOption.SilverMist -> if (dark) mistDark else mistLight
    AppThemeOption.SoftClay -> if (dark) clayDark else clayLight
}

// ---------------------------------------------------------------------------
// Paper - the authored signature scheme.
//
// Light: warm paper surfaces with cobalt primary, sage secondary, and clay
// tertiary. Dark: deep navy surfaces with the same three accents lifted for
// contrast. All role pairs below are authored, not derived, so each theme stays
// cohesive and accessible.
// ---------------------------------------------------------------------------

private val foldedSignalLight = lightColorScheme(
    primary = Color(0xFF2B4ACB),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFDCE1FF),
    onPrimaryContainer = Color(0xFF0A1B5C),
    secondary = Color(0xFF3E6B4F),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFD7E8DA),
    onSecondaryContainer = Color(0xFF0E2A18),
    tertiary = Color(0xFF9C5F38),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFFF6DBC8),
    onTertiaryContainer = Color(0xFF3A1D0B),
    background = Color(0xFFF3F0E7),
    onBackground = Color(0xFF1E1D1A),
    surface = Color(0xFFFBF8F1),
    onSurface = Color(0xFF1E1D1A),
    surfaceVariant = Color(0xFFE9E6DC),
    onSurfaceVariant = Color(0xFF5E5C54),
    surfaceTint = Color(0xFF2B4ACB),
    inverseSurface = Color(0xFF303036),
    inverseOnSurface = Color(0xFFF2F0EA),
    inversePrimary = Color(0xFFA7B4F5),
    outline = Color(0xFF85837A),
    outlineVariant = Color(0xFFD8D4C9),
    scrim = Color(0xFF000000),
    error = Color(0xFFB3261E),
    onError = Color(0xFFFFFFFF),
    errorContainer = Color(0xFFF9DEDC),
    onErrorContainer = Color(0xFF410E0B),
    surfaceBright = Color(0xFFFBF8F1),
    surfaceDim = Color(0xFFF3F0E7),
    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFFDFBF6),
    surfaceContainer = Color(0xFFF5F2EA),
    surfaceContainerHigh = Color(0xFFEFECE3),
    surfaceContainerHighest = Color(0xFFE9E6DD)
)

private val foldedSignalDark = darkColorScheme(
    primary = Color(0xFFA7B4F5),
    onPrimary = Color(0xFF0A1B5C),
    primaryContainer = Color(0xFF2C3A6E),
    onPrimaryContainer = Color(0xFFDCE1FF),
    secondary = Color(0xFF9CC7AC),
    onSecondary = Color(0xFF0E2A18),
    secondaryContainer = Color(0xFF24463A),
    onSecondaryContainer = Color(0xFFD7E8DA),
    tertiary = Color(0xFFE0A37C),
    onTertiary = Color(0xFF3A1D0B),
    tertiaryContainer = Color(0xFF5C3A22),
    onTertiaryContainer = Color(0xFFF6DBC8),
    background = Color(0xFF0E1420),
    onBackground = Color(0xFFE7E4DC),
    surface = Color(0xFF141B2A),
    onSurface = Color(0xFFE7E4DC),
    surfaceVariant = Color(0xFF1B2436),
    onSurfaceVariant = Color(0xFFB6B2A8),
    surfaceTint = Color(0xFFA7B4F5),
    inverseSurface = Color(0xFFE7E4DC),
    inverseOnSurface = Color(0xFF2B2B30),
    inversePrimary = Color(0xFF2B4ACB),
    outline = Color(0xFF8B887E),
    outlineVariant = Color(0xFF353A46),
    scrim = Color(0xFF000000),
    error = Color(0xFFF2B8B5),
    onError = Color(0xFF601410),
    errorContainer = Color(0xFF8C1D18),
    onErrorContainer = Color(0xFFF9DEDC),
    surfaceBright = Color(0xFF1B2436),
    surfaceDim = Color(0xFF0E1420),
    surfaceContainerLowest = Color(0xFF090E18),
    surfaceContainerLow = Color(0xFF121826),
    surfaceContainer = Color(0xFF161D2C),
    surfaceContainerHigh = Color(0xFF202836),
    surfaceContainerHighest = Color(0xFF2B3342)
)

// ---------------------------------------------------------------------------
// Legacy authored schemes. These remain available so stored theme ids keep
// compiling and resolving; only "paper" is authored above.
// ---------------------------------------------------------------------------

private data class Palette(
    val grouped: Color,
    val paper: Color,
    val raised: Color,
    val primaryText: Color,
    val secondaryText: Color,
    val separator: Color,
    val dark: Boolean
)

private val indigoLight = Color(0.25f, 0.28f, 0.72f)
private val indigoDark = Color(0.68f, 0.72f, 1f)

private fun Palette.toMaterialScheme(): ColorScheme {
    val primary = if (dark) indigoDark else indigoLight
    val onPrimary = if (dark) Color(0.04f, 0.05f, 0.06f) else Color.White
    val primaryContainer = lerp(paper, primary, if (dark) 0.24f else 0.14f)
    val onPrimaryContainer = if (dark) lerp(primaryText, primary, 0.24f) else lerp(primaryText, primary, 0.42f)
    val secondary = if (dark) Color(0.50f, 0.82f, 0.65f) else Color(0.12f, 0.38f, 0.27f)
    val secondaryContainer = lerp(paper, secondary, if (dark) 0.22f else 0.12f)
    val tertiary = if (dark) Color(0.85f, 0.60f, 0.90f) else Color(0.48f, 0.20f, 0.52f)
    val tertiaryContainer = lerp(paper, tertiary, if (dark) 0.22f else 0.12f)
    val high = lerp(raised, primary, if (dark) 0.08f else 0.035f)
    val highest = lerp(raised, primary, if (dark) 0.14f else 0.065f)

    return if (dark) {
        darkColorScheme(
            primary = primary,
            onPrimary = onPrimary,
            primaryContainer = primaryContainer,
            onPrimaryContainer = onPrimaryContainer,
            secondary = secondary,
            onSecondary = Color(0.04f, 0.05f, 0.06f),
            secondaryContainer = secondaryContainer,
            onSecondaryContainer = primaryText,
            tertiary = tertiary,
            onTertiary = Color(0.04f, 0.05f, 0.06f),
            tertiaryContainer = tertiaryContainer,
            onTertiaryContainer = primaryText,
            background = grouped,
            onBackground = primaryText,
            surface = paper,
            onSurface = primaryText,
            surfaceVariant = raised,
            onSurfaceVariant = secondaryText,
            surfaceTint = primary,
            inverseSurface = primaryText,
            inverseOnSurface = grouped,
            inversePrimary = indigoLight,
            outline = lerp(secondaryText, primaryText, 0.18f),
            outlineVariant = separator,
            scrim = Color.Black,
            surfaceBright = raised,
            surfaceDim = grouped,
            surfaceContainerLowest = paper,
            surfaceContainerLow = raised,
            surfaceContainer = paper,
            surfaceContainerHigh = high,
            surfaceContainerHighest = highest
        )
    } else {
        lightColorScheme(
            primary = primary,
            onPrimary = onPrimary,
            primaryContainer = primaryContainer,
            onPrimaryContainer = onPrimaryContainer,
            secondary = secondary,
            onSecondary = Color.White,
            secondaryContainer = secondaryContainer,
            onSecondaryContainer = primaryText,
            tertiary = tertiary,
            onTertiary = Color.White,
            tertiaryContainer = tertiaryContainer,
            onTertiaryContainer = primaryText,
            background = grouped,
            onBackground = primaryText,
            surface = paper,
            onSurface = primaryText,
            surfaceVariant = raised,
            onSurfaceVariant = secondaryText,
            surfaceTint = primary,
            inverseSurface = primaryText,
            inverseOnSurface = paper,
            inversePrimary = indigoDark,
            outline = lerp(secondaryText, primaryText, 0.12f),
            outlineVariant = separator,
            scrim = Color.Black,
            surfaceBright = raised,
            surfaceDim = grouped,
            surfaceContainerLowest = raised,
            surfaceContainerLow = paper,
            surfaceContainer = grouped,
            surfaceContainerHigh = high,
            surfaceContainerHighest = highest
        )
    }
}

private fun rgb(red: Int, green: Int, blue: Int) = Color(red, green, blue)
private fun lightSeparator(grouped: Color, opacity: Float = 0.12f) = lerp(grouped, Color.Black, opacity)
private fun darkSeparator(grouped: Color, opacity: Float = 0.16f) = lerp(grouped, Color.White, opacity)

private val porcelainPalette = Palette(
    grouped = Color.White, paper = Color.White, raised = Color(0.975f, 0.975f, 0.980f),
    primaryText = Color(0.055f, 0.065f, 0.075f), secondaryText = Color(0.34f, 0.36f, 0.39f),
    separator = lerp(Color.White, Color.Black, 0.14f), dark = false
)
private val midnightPalette = Palette(
    grouped = Color.Black, paper = Color.Black, raised = Color(0.055f, 0.055f, 0.060f),
    primaryText = Color(0.96f, 0.96f, 0.97f), secondaryText = Color(0.68f, 0.70f, 0.73f),
    separator = lerp(Color.Black, Color.White, 0.18f), dark = true
)
private val mistLightPalette = Palette(
    grouped = Color(0.935f, 0.950f, 0.965f), paper = Color(0.975f, 0.982f, 0.990f), raised = Color.White,
    primaryText = Color(0.075f, 0.095f, 0.120f), secondaryText = Color(0.34f, 0.39f, 0.44f),
    separator = lightSeparator(Color(0.935f, 0.950f, 0.965f)), dark = false
)
private val mistDarkPalette = Palette(
    grouped = Color(0.055f, 0.070f, 0.085f), paper = Color(0.075f, 0.092f, 0.108f), raised = Color(0.105f, 0.125f, 0.145f),
    primaryText = Color(0.925f, 0.945f, 0.965f), secondaryText = Color(0.65f, 0.70f, 0.75f),
    separator = darkSeparator(Color(0.055f, 0.070f, 0.085f)), dark = true
)
private val clayLightPalette = Palette(
    grouped = Color(0.948f, 0.925f, 0.905f), paper = Color(0.985f, 0.968f, 0.950f), raised = Color(1f, 0.987f, 0.973f),
    primaryText = Color(0.145f, 0.115f, 0.105f), secondaryText = Color(0.40f, 0.34f, 0.31f),
    separator = lightSeparator(Color(0.948f, 0.925f, 0.905f), 0.13f), dark = false
)
private val clayDarkPalette = Palette(
    grouped = Color(0.090f, 0.072f, 0.066f), paper = Color(0.115f, 0.092f, 0.083f), raised = Color(0.155f, 0.125f, 0.112f),
    primaryText = Color(0.955f, 0.925f, 0.900f), secondaryText = Color(0.72f, 0.65f, 0.61f),
    separator = darkSeparator(Color(0.090f, 0.072f, 0.066f)), dark = true
)

private val porcelain = porcelainPalette.toMaterialScheme()
private val midnight = midnightPalette.toMaterialScheme()
private val mistLight = mistLightPalette.toMaterialScheme()
private val mistDark = mistDarkPalette.toMaterialScheme()
private val clayLight = clayLightPalette.toMaterialScheme()
private val clayDark = clayDarkPalette.toMaterialScheme()
