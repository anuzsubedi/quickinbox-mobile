package dev.anuz.quickinbox.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ---------------------------------------------------------------------------
// SenderTile — a deterministic contact avatar.
// ---------------------------------------------------------------------------

/** Immutable background/foreground pair used to render a sender tile. */
@Immutable
data class SenderTileColors(val background: Color, val foreground: Color)

private val SenderPalette = listOf(
    SenderTileColors(Color(0xFF2E4ACB), Color(0xFFFFFFFF)), // cobalt
    SenderTileColors(Color(0xFF3E6B4F), Color(0xFFFFFFFF)), // sage
    SenderTileColors(Color(0xFF9C5F38), Color(0xFFFFFFFF)), // clay
    SenderTileColors(Color(0xFF5B4B9E), Color(0xFFFFFFFF)), // violet
    SenderTileColors(Color(0xFFA34D68), Color(0xFFFFFFFF)), // berry
    SenderTileColors(Color(0xFF2E7D72), Color(0xFFFFFFFF))  // teal
)

/**
 * A contact avatar that is fully deterministic: the same [name] always resolves to the same
 * color pair and initials, so a sender is stable across lists, themes, and sessions.
 *
 * @param name display name used to derive initials and color. Emails or fallback text work too.
 * @param contentDescription accessibility label. Leave null when the sender name is rendered
 *   adjacently (the tile is then treated as decorative). Defaults to null.
 */
@Composable
fun SenderTile(
    name: String,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    shape: Shape = CircleShape,
    contentDescription: String? = null
) {
    val colors = senderTileColors(name)
    val initials = senderInitials(name)
    Box(
        modifier = modifier
            .size(size)
            .clip(shape)
            .background(colors.background)
            .semantics {
                if (contentDescription != null) this.contentDescription = contentDescription
            },
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = initials,
            color = colors.foreground,
            fontSize = (size.value * 0.38f).sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1
        )
    }
}

/** Derives up to two uppercase initials from a display name. Deterministic and non-empty. */
internal fun senderInitials(name: String): String {
    val tokens = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
    val letters = tokens.take(2).map { it.first().uppercaseChar() }
    return if (letters.isEmpty()) "?" else letters.joinToString("")
}

/** Resolves the deterministic color pair for a sender name. */
internal fun senderTileColors(name: String): SenderTileColors =
    SenderPalette[stableIndex(name, SenderPalette.size)]

private fun stableIndex(text: String, size: Int): Int {
    var hash = 0x811c9dc5.toInt() // FNV-1a 32-bit offset basis
    for (char in text) {
        hash = (hash xor char.code) * 0x01000193
    }
    return Math.floorMod(hash, size)
}

// ---------------------------------------------------------------------------
// UnreadRail — a vertical unread indicator that preserves row alignment.
// ---------------------------------------------------------------------------

private const val UnreadStateDescription = "Unread"

/**
 * A thin vertical rail for the leading edge of a list row. When [unread] is true it draws a
 * colored bar and announces "Unread"; when false it still reserves the same width so read and
 * unread rows stay aligned. Place it inside a row whose height is already constrained.
 */
@Composable
fun UnreadRail(
    unread: Boolean,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
    width: Dp = 3.dp,
    shape: Shape = CircleShape
) {
    Box(
        modifier = modifier
            .width(width)
            .fillMaxHeight()
            .then(
                if (unread) {
                    Modifier
                        .background(color, shape)
                        .semantics { stateDescription = UnreadStateDescription }
                } else {
                    Modifier
                }
            )
    )
}

// ---------------------------------------------------------------------------
// RuleDivider — a horizontal rule with an optional section label.
// ---------------------------------------------------------------------------

/**
 * A horizontal rule. With a [label] it renders "— label —" style section rule and exposes the
 * label as a heading for screen readers; without one it is purely decorative.
 */
@Composable
fun RuleDivider(
    modifier: Modifier = Modifier,
    label: String? = null,
    color: Color = MaterialTheme.colorScheme.outlineVariant,
    labelColor: Color = MaterialTheme.colorScheme.onSurfaceVariant
) {
    if (label == null) {
        HorizontalDivider(modifier = modifier, thickness = 1.dp, color = color)
    } else {
        Row(
            modifier = modifier,
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            HorizontalDivider(Modifier.weight(1f), thickness = 1.dp, color = color)
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = labelColor,
                maxLines = 1,
                modifier = Modifier.semantics { heading() }
            )
            HorizontalDivider(Modifier.weight(1f), thickness = 1.dp, color = color)
        }
    }
}
