package dev.anuz.quickinbox.ui.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

internal val Green = Color(0xFF195C3B)
internal val PaleGreen = Color(0xFFDDEFE3)
internal val Canvas = Color(0xFFF8FAF7)
internal val Ink = Color(0xFF17211B)
internal val Muted = Color(0xFF5C6B62)

internal val FallbackLight = lightColorScheme(
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

internal val FallbackDark = darkColorScheme(
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
