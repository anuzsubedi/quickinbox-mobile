package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.withTransform

@Composable
internal fun InboxSwipeIcon(progress: Float, color: Color, modifier: Modifier) {
    val travel = archiveArrowTravel(progress)
    SwipeIconCanvas(modifier) {
        archiveGlyph(color)
        withTransform({ translate(0f, -travel) }) {
            inkLine(color, 12f, 19f, 12f, 14f)
            contour(color) { moveTo(9f, 17f); lineTo(12f, 14f); lineTo(15f, 17f) }
        }
    }
}
