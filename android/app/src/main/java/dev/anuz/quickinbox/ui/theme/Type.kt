package dev.anuz.quickinbox.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import dev.anuz.quickinbox.R

/**
 * Bricolage Grotesque is reserved exclusively for the QuickInbox wordmark and intentional
 * branding moments. Functional interface text must never use it; see [QuickInboxTypography]
 * and the `QuickInboxWordmark` component.
 */
internal val BricolageGrotesque = FontFamily(
    Font(R.font.bricolage_grotesque_medium, FontWeight(560)),
    Font(R.font.bricolage_grotesque_semibold, FontWeight(620))
)

/** Material defaults are pinned to the Android system font so no custom face leaks into UI text. */
private val MaterialDefaults = Typography()

private fun TextStyle.systemDefault() = copy(fontFamily = FontFamily.Default)

/**
 * The app-wide Material typography. Every functional style explicitly uses
 * `FontFamily.Default` (the Android system font) while preserving Material 3 sizes,
 * weights, and line heights. Bricolage Grotesque is intentionally absent from this set.
 */
val QuickInboxTypography = Typography(
    displayLarge = MaterialDefaults.displayLarge.systemDefault(),
    displayMedium = MaterialDefaults.displayMedium.systemDefault(),
    displaySmall = MaterialDefaults.displaySmall.systemDefault(),
    headlineLarge = MaterialDefaults.headlineLarge.systemDefault(),
    headlineMedium = MaterialDefaults.headlineMedium.systemDefault(),
    headlineSmall = MaterialDefaults.headlineSmall.systemDefault(),
    titleLarge = MaterialDefaults.titleLarge.systemDefault(),
    titleMedium = MaterialDefaults.titleMedium.systemDefault(),
    titleSmall = MaterialDefaults.titleSmall.systemDefault(),
    bodyLarge = MaterialDefaults.bodyLarge.systemDefault(),
    bodyMedium = MaterialDefaults.bodyMedium.systemDefault(),
    bodySmall = MaterialDefaults.bodySmall.systemDefault(),
    labelLarge = MaterialDefaults.labelLarge.systemDefault(),
    labelMedium = MaterialDefaults.labelMedium.systemDefault(),
    labelSmall = MaterialDefaults.labelSmall.systemDefault()
)
