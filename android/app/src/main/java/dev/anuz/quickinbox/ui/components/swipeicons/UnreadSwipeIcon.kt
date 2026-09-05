package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
internal fun UnreadSwipeIcon(progress: Float, color: Color, modifier: Modifier) {
    val pose = envelopeTransferPose(1f - progress)
    SwipeIconCanvas(modifier) { envelopeGlyph(color, pose) }
}
