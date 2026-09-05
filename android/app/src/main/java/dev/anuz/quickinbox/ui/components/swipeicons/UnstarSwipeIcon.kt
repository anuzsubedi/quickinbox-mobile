package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.clipRect

@Composable
internal fun UnstarSwipeIcon(progress: Float, color: Color, modifier: Modifier) {
    val shape = remember { starPath() }
    val fill = 1f - progress.coerceIn(0f, 1f)
    SwipeIconCanvas(modifier) {
        // The fill level follows the finger across the entire animation range.
        clipRect(top = 19.8f - 16.8f * fill) {
            drawPath(shape, color)
        }
        drawPath(shape, color, style = IconStroke)
    }
}
