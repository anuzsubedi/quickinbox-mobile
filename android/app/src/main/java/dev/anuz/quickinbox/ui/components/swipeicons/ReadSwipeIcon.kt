package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
internal fun ReadSwipeIcon(progress: Float, color: Color, modifier: Modifier) {
    val pose = envelopeTransferPose(progress)
    SwipeIconCanvas(modifier) { envelopeGlyph(color, pose) }
}
