package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath

@Composable
internal fun RestoreSwipeIcon(progress: Float, color: Color, modifier: Modifier) {
    val settle = phase(progress)
    val front = remember { Path().apply {
        moveTo(3f, 13f); lineTo(8f, 13f); lineTo(9.5f, 16f)
        lineTo(14.5f, 16f); lineTo(16f, 13f); lineTo(21f, 13f)
        lineTo(21f, 19f); quadraticTo(21f, 21f, 19f, 21f)
        lineTo(5f, 21f); quadraticTo(3f, 21f, 3f, 19f); close()
    } }
    SwipeIconCanvas(modifier) {
        // Follow the actual notched pocket, so the letter never vanishes at an invisible line.
        clipPath(front, clipOp = ClipOp.Difference) {
            paper(color, 7.5f, 2f + 8f * settle, 9f, 10f)
        }
        contour(color) {
            moveTo(3f, 13f); lineTo(5f, 8f); lineTo(5f, 7f)
            moveTo(21f, 13f); lineTo(19f, 8f); lineTo(19f, 7f)
        }
        drawPath(front, color, style = IconStroke)
    }
}
