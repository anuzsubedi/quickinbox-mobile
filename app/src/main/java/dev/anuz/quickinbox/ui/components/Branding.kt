package dev.anuz.quickinbox.ui.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import dev.anuz.quickinbox.ui.theme.BricolageGrotesque

/**
 * The QuickInbox wordmark. This is the only place Bricolage Grotesque should be used.
 * Functional text must use the app typography (which is pinned to the Android system font)
 * and should not pass through this component.
 *
 * The wordmark is an ordinary [Text], so the brand name itself remains readable by screen
 * readers. Use [fontSize] to scale it; the line height and letter spacing are derived
 * automatically to keep the mark optically consistent at any size.
 */
@Composable
fun QuickInboxWordmark(
    text: String = "QuickInbox",
    modifier: Modifier = Modifier,
    fontSize: TextUnit = 20.sp,
    color: Color = Color.Unspecified,
    maxLines: Int = 1,
    overflow: TextOverflow = TextOverflow.Clip
) {
    Text(
        text = text,
        modifier = modifier,
        color = color,
        maxLines = maxLines,
        overflow = overflow,
        style = wordmarkTextStyle(fontSize)
    )
}

@Composable
internal fun wordmarkTextStyle(fontSize: TextUnit): TextStyle = TextStyle(
    fontFamily = BricolageGrotesque,
    fontWeight = FontWeight(620),
    fontSize = fontSize,
    lineHeight = fontSize,
    letterSpacing = (-0.03).em,
    platformStyle = PlatformTextStyle(includeFontPadding = false),
    lineHeightStyle = LineHeightStyle(
        alignment = LineHeightStyle.Alignment.Center,
        trim = LineHeightStyle.Trim.Both
    )
)
