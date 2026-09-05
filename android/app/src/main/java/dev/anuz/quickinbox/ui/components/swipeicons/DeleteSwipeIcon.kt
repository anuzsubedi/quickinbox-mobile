package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
internal fun DeleteSwipeIcon(progress: Float, color: Color, modifier: Modifier) {
    val pose = binTransferPose(progress)
    SwipeIconCanvas(modifier) { binTransferGlyph(color, pose) }
}
