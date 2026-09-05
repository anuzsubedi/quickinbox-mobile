package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform

/** Shared optical grid and stroke weight; each action owns its geometry and motion. */
@Composable
internal fun SwipeIconCanvas(modifier: Modifier, draw: DrawScope.() -> Unit) {
    Canvas(modifier) {
        val unit = size.minDimension / 24f
        withTransform({
            translate((size.width - unit * 24f) / 2f, (size.height - unit * 24f) / 2f)
            scale(unit, unit, Offset.Zero)
        }, draw)
    }
}

internal val IconStroke = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)
internal fun DrawScope.contour(color: Color, block: Path.() -> Unit) = drawPath(Path().apply(block), color, style = IconStroke)
internal fun DrawScope.inkLine(color: Color, x1: Float, y1: Float, x2: Float, y2: Float) =
    drawLine(color, Offset(x1, y1), Offset(x2, y2), 1.8f, StrokeCap.Round)
internal fun phase(progress: Float, from: Float = 0f, to: Float = 1f): Float {
    val p = ((progress - from) / (to - from)).coerceIn(0f, 1f)
    return p * p * (3f - 2f * p)
}
internal fun starPath() = Path().apply {
    moveTo(12f, 3f); lineTo(14.7f, 8.6f); lineTo(20.8f, 9.4f)
    lineTo(16.4f, 13.7f); lineTo(17.5f, 19.8f); lineTo(12f, 16.9f)
    lineTo(6.5f, 19.8f); lineTo(7.6f, 13.7f); lineTo(3.2f, 9.4f)
    lineTo(9.3f, 8.6f); close()
}
internal fun DrawScope.binBody(color: Color) = contour(color) {
    moveTo(6f, 9f); lineTo(7f, 19f); quadraticTo(7.2f, 21f, 9f, 21f)
    lineTo(15f, 21f); quadraticTo(16.8f, 21f, 17f, 19f); lineTo(18f, 9f)
}
internal fun DrawScope.binLid(color: Color) {
    inkLine(color, 4f, 7f, 20f, 7f)
    contour(color) { moveTo(9f, 7f); lineTo(9f, 4f); lineTo(15f, 4f); lineTo(15f, 7f) }
}

internal fun DrawScope.paper(color: Color, x: Float, y: Float, width: Float = 8f, height: Float = 9f) {
    drawRoundRect(color, Offset(x, y), androidx.compose.ui.geometry.Size(width, height),
        androidx.compose.ui.geometry.CornerRadius(1f), style = IconStroke)
    inkLine(color.copy(alpha = color.alpha * 0.65f), x + 2f, y + 3f, x + width - 2f, y + 3f)
    inkLine(color.copy(alpha = color.alpha * 0.65f), x + 2f, y + 5.5f, x + width - 3f, y + 5.5f)
}
internal fun DrawScope.trace(color: Color, path: Path, fraction: Float) {
    val measure = androidx.compose.ui.graphics.PathMeasure().apply { setPath(path, false) }
    val segment = Path()
    measure.getSegment(0f, measure.length * fraction.coerceIn(0f, 1f), segment, true)
    drawPath(segment, color, style = IconStroke)
}
