package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.clipRect

/** The front pocket masks the letter along its V-shaped opening, not a horizontal cut. */
internal fun DrawScope.envelopeGlyph(color: Color, pose: EnvelopeTransferPose) {
    val pocket = Path().apply {
        moveTo(3.5f, 8f); lineTo(11f, 13.5f)
        quadraticTo(12f, 14.3f, 13f, 13.5f); lineTo(20.5f, 8f)
        lineTo(20.5f, 19f); quadraticTo(20.5f, 21f, 18.5f, 21f)
        lineTo(5.5f, 21f); quadraticTo(3.5f, 21f, 3.5f, 19f); close()
    }
    val letterMask = Path().apply { addRect(Rect(6.6f, pose.letterY - 0.9f, 17.4f, pose.letterY + 10.9f)) }
    clipPath(letterMask, clipOp = ClipOp.Difference) {
        contour(color) {
            moveTo(3.5f, 8f); lineTo(11f, 13.5f - 10f * pose.flap)
            quadraticTo(12f, 14.3f - 10f * pose.flap, 13f, 13.5f - 10f * pose.flap)
            lineTo(20.5f, 8f)
        }
    }
    clipRect(bottom = 20f) {
        clipPath(pocket, clipOp = ClipOp.Difference) {
            paper(color, 7.5f, pose.letterY, 9f, 10f)
        }
    }
    drawPath(pocket, color, style = IconStroke)
    // The top edge belongs to the closed envelope and folds away as it opens.
    inkLine(color.copy(alpha = color.alpha * (1f - pose.flap)), 4f, 8f, 20f, 8f)
    val seams = color.copy(alpha = color.alpha * 0.35f)
    inkLine(seams, 4.8f, 19.7f, 8.5f, 16f)
    inkLine(seams, 19.2f, 19.7f, 15.5f, 16f)
}
