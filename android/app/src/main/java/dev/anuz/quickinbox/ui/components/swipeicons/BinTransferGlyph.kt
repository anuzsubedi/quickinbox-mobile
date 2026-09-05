package dev.anuz.quickinbox.ui.components.swipeicons

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform

internal fun DrawScope.binTransferGlyph(color: Color, pose: BinTransferPose) {
    clipRect(bottom = 9f) {
        withTransform({ rotate(pose.fileAngle, Offset(12f, pose.fileY + 3f)) }) {
            paper(color, 9f, pose.fileY, 6f, 8f)
        }
    }
    binBody(color)
    inkLine(color.copy(alpha = color.alpha * 0.65f), 10f, 11f, 10.4f, 17f)
    inkLine(color.copy(alpha = color.alpha * 0.65f), 14f, 11f, 13.6f, 17f)
    // Swing to the side to leave a clear opening for the file.
    withTransform({ translate(-2f * pose.lid, -1.5f * pose.lid); rotate(-18f * pose.lid, Offset(12f, 7f)) }) {
        binLid(color)
    }
}
