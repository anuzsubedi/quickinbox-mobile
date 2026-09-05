package dev.anuz.quickinbox.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.max
import kotlin.math.min

class ThemePaletteTest {
    @Test
    fun authoredThemesKeepTextReadableAcrossSurfaceAndAccentRoles() {
        forEachScheme { name, _, scheme ->
            val pairs = listOf(
                scheme.onSurface to scheme.surface,
                scheme.onSurfaceVariant to scheme.surfaceContainerLow,
                scheme.onSurfaceVariant to scheme.surfaceContainerHighest,
                scheme.onPrimary to scheme.primary,
                scheme.onPrimaryContainer to scheme.primaryContainer,
                scheme.onSecondary to scheme.secondary,
                scheme.onSecondaryContainer to scheme.secondaryContainer,
                scheme.onTertiary to scheme.tertiary,
                scheme.onTertiaryContainer to scheme.tertiaryContainer,
                scheme.onError to scheme.error,
                scheme.onErrorContainer to scheme.errorContainer
            )
            pairs.forEachIndexed { index, (foreground, background) ->
                assertTrue("$name role pair $index contrast ${contrast(foreground, background)}", contrast(foreground, background) >= 4.5f)
            }
        }
    }

    @Test
    fun cardsAreDistinctInLightThemesAndSubtleInDarkThemes() {
        forEachScheme { name, dark, scheme ->
            val ratio = contrast(scheme.surface, scheme.surfaceContainerLow)
            assertTrue("$name settings surface contrast $ratio", ratio in (if (dark) 1.04f else 1.10f)..1.25f)
        }
    }

    @Test
    fun containerLevelsRemainOrdered() {
        forEachScheme { name, dark, scheme ->
            val levels = listOf(scheme.surface, scheme.surfaceContainerLow, scheme.surfaceContainer,
                scheme.surfaceContainerHigh, scheme.surfaceContainerHighest).map { it.luminance() }
            levels.zipWithNext().forEach { (a, b) ->
                assertTrue("$name inverted surface roles", if (dark) b > a else b < a)
            }
        }
    }

    private fun forEachScheme(check: (String, Boolean, androidx.compose.material3.ColorScheme) -> Unit) {
        AppThemeOption.entries.forEach { option ->
            (option.forcedDark?.let { listOf(it) } ?: listOf(false, true)).forEach { dark ->
                check("${option.title} dark=$dark", dark, option.materialScheme(dark))
            }
        }
    }

    private fun contrast(a: Color, b: Color): Float =
        (max(a.luminance(), b.luminance()) + 0.05f) / (min(a.luminance(), b.luminance()) + 0.05f)
}
