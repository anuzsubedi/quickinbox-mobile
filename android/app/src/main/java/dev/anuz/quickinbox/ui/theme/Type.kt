package dev.anuz.quickinbox.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
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

/** Bundled UI fonts keep typography consistent on every device and offline. */
internal val GoogleSans = FontFamily(
    Font(R.font.google_sans_regular, FontWeight.Normal),
    Font(R.font.google_sans_medium, FontWeight.Medium),
    Font(R.font.google_sans_semibold, FontWeight.SemiBold),
    Font(R.font.google_sans_bold, FontWeight.Bold),
    Font(R.font.google_sans_italic, FontWeight.Normal, FontStyle.Italic),
    Font(R.font.google_sans_medium_italic, FontWeight.Medium, FontStyle.Italic),
    Font(R.font.google_sans_semibold_italic, FontWeight.SemiBold, FontStyle.Italic),
    Font(R.font.google_sans_bold_italic, FontWeight.Bold, FontStyle.Italic)
)

private val MaterialDefaults = Typography()
private fun TextStyle.googleSans() = copy(fontFamily = GoogleSans)

/** Google Sans interface typography with the standard Material 3 type scale. */
val QuickInboxTypography = Typography(
    displayLarge = MaterialDefaults.displayLarge.googleSans(),
    displayMedium = MaterialDefaults.displayMedium.googleSans(),
    displaySmall = MaterialDefaults.displaySmall.googleSans(),
    headlineLarge = MaterialDefaults.headlineLarge.googleSans(),
    headlineMedium = MaterialDefaults.headlineMedium.googleSans(),
    headlineSmall = MaterialDefaults.headlineSmall.googleSans(),
    titleLarge = MaterialDefaults.titleLarge.googleSans(),
    titleMedium = MaterialDefaults.titleMedium.googleSans(),
    titleSmall = MaterialDefaults.titleSmall.googleSans(),
    bodyLarge = MaterialDefaults.bodyLarge.googleSans(),
    bodyMedium = MaterialDefaults.bodyMedium.googleSans(),
    bodySmall = MaterialDefaults.bodySmall.googleSans(),
    labelLarge = MaterialDefaults.labelLarge.googleSans(),
    labelMedium = MaterialDefaults.labelMedium.googleSans(),
    labelSmall = MaterialDefaults.labelSmall.googleSans()
)
