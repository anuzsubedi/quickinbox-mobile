package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope

/** Complete archive silhouette, with a separate clear area for the moving arrow. */
internal fun DrawScope.archiveGlyph(color: Color) {
    contour(color) {
        moveTo(4f, 7f); lineTo(4f, 19f)
        quadraticTo(4f, 21f, 6f, 21f); lineTo(18f, 21f)
        quadraticTo(20f, 21f, 20f, 19f); lineTo(20f, 7f)
    }
    drawRoundRect(color, Offset(3f, 3f), Size(18f, 4f), CornerRadius(1f), style = IconStroke)
}
