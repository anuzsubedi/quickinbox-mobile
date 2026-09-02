package dev.anuz.quickinbox.ui.components

import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Archive
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.MarkEmailRead
import androidx.compose.material.icons.rounded.RestoreFromTrash
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Unarchive
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.airbnb.lottie.LottieProperty
import com.airbnb.lottie.compose.LottieAnimation
import com.airbnb.lottie.compose.LottieCompositionSpec
import com.airbnb.lottie.compose.rememberLottieComposition
import com.airbnb.lottie.compose.rememberLottieDynamicProperties
import com.airbnb.lottie.compose.rememberLottieDynamicProperty
import dev.anuz.quickinbox.R
import dev.anuz.quickinbox.data.SwipeControl
import dev.anuz.quickinbox.domain.MailAction

val SwipeControl.fallbackIcon: ImageVector
    get() = when (this) {
        SwipeControl.None -> Icons.Rounded.Block
        SwipeControl.ToggleRead -> Icons.Rounded.MarkEmailRead
        SwipeControl.ToggleStar -> Icons.Rounded.Star
        SwipeControl.Archive -> Icons.Rounded.Archive
        SwipeControl.MoveToInbox -> Icons.Rounded.Unarchive
        SwipeControl.Trash, SwipeControl.Delete -> Icons.Rounded.Delete
        SwipeControl.Restore -> Icons.Rounded.RestoreFromTrash
    }

private val SwipeControl.lottieResource: Int?
    get() = when (this) {
        SwipeControl.None -> null
        SwipeControl.ToggleRead -> R.raw.swipe_mail_open
        SwipeControl.ToggleStar -> R.raw.swipe_star
        SwipeControl.Archive, SwipeControl.MoveToInbox, SwipeControl.Restore -> null
        SwipeControl.Trash, SwipeControl.Delete -> R.raw.swipe_trash
    }

@Composable
fun SwipeControlIcon(
    control: SwipeControl,
    progress: Float,
    color: Color,
    modifier: Modifier = Modifier,
    resolvedAction: MailAction? = null
) {
    if (control == SwipeControl.Archive || control == SwipeControl.MoveToInbox || control == SwipeControl.Restore) {
        BoxTransferIcon(
            progress = progress,
            movesIntoBox = control == SwipeControl.Archive,
            color = color,
            modifier = modifier
        )
        return
    }

    val resource = control.lottieResource
    if (resource == null) {
        Icon(control.fallbackIcon, contentDescription = control.title, modifier = modifier, tint = color)
        return
    }

    val composition by rememberLottieComposition(LottieCompositionSpec.RawRes(resource))
    if (composition == null) {
        Icon(control.fallbackIcon, contentDescription = control.title, modifier = modifier, tint = color)
        return
    }

    val colorFilter = PorterDuffColorFilter(color.toArgb(), PorterDuff.Mode.SRC_ATOP)
    val dynamicProperties = rememberLottieDynamicProperties(
        rememberLottieDynamicProperty(
            property = LottieProperty.COLOR_FILTER,
            value = colorFilter,
            keyPath = arrayOf("**")
        )
    )
    val gestureProgress = progress.coerceIn(0f, 1f)
    val directionalProgress = when {
        resolvedAction == MailAction.Star -> gestureProgress * 0.5f
        resolvedAction == MailAction.Unstar -> (1f - gestureProgress) * 0.5f
        resolvedAction == null && control == SwipeControl.ToggleStar -> 0.5f
        resolvedAction == MailAction.Unread -> 1f - (gestureProgress * 0.5f)
        else -> gestureProgress
    }
    val normalizedModifier = when (control) {
        SwipeControl.ToggleRead -> modifier.padding(2.dp)
        SwipeControl.ToggleStar, SwipeControl.Trash, SwipeControl.Delete -> modifier.padding(4.dp)
        else -> modifier
    }
    LottieAnimation(
        composition = composition,
        progress = { directionalProgress },
        modifier = normalizedModifier,
        contentScale = ContentScale.Fit,
        dynamicProperties = dynamicProperties
    )
}

@Composable
private fun BoxTransferIcon(
    progress: Float,
    movesIntoBox: Boolean,
    color: Color,
    modifier: Modifier = Modifier
) {
    Canvas(modifier) {
        val unit = size.minDimension
        val left = (size.width - unit) / 2f
        val top = (size.height - unit) / 2f
        val strokeWidth = unit * 0.065f
        val stroke = Stroke(
            width = strokeWidth,
            cap = StrokeCap.Round,
            join = StrokeJoin.Round
        )
        val boxLeft = left + unit * 0.26f
        val boxTop = top + unit * 0.46f
        val boxSize = unit * 0.48f
        drawRoundRect(
            color = color,
            topLeft = Offset(boxLeft, boxTop),
            size = Size(boxSize, boxSize),
            cornerRadius = CornerRadius(unit * 0.055f),
            style = stroke
        )

        val gestureProgress = progress.coerceIn(0f, 1f)
        val centerX = left + unit * 0.50f
        if (movesIntoBox) {
            val travel = unit * 0.25f * gestureProgress
            val tipY = top + unit * 0.43f + travel
            val stemTop = top + unit * 0.15f + travel
            drawLine(color, Offset(centerX, stemTop), Offset(centerX, tipY), strokeWidth, StrokeCap.Round)
            drawLine(
                color,
                Offset(centerX - unit * 0.13f, tipY - unit * 0.13f),
                Offset(centerX, tipY),
                strokeWidth,
                StrokeCap.Round
            )
            drawLine(
                color,
                Offset(centerX + unit * 0.13f, tipY - unit * 0.13f),
                Offset(centerX, tipY),
                strokeWidth,
                StrokeCap.Round
            )
        } else {
            val travel = unit * 0.34f * gestureProgress
            val tipY = top + unit * 0.57f - travel
            val stemBottom = top + unit * 0.80f - travel
            drawLine(color, Offset(centerX, stemBottom), Offset(centerX, tipY), strokeWidth, StrokeCap.Round)
            drawLine(
                color,
                Offset(centerX - unit * 0.13f, tipY + unit * 0.13f),
                Offset(centerX, tipY),
                strokeWidth,
                StrokeCap.Round
            )
            drawLine(
                color,
                Offset(centerX + unit * 0.13f, tipY + unit * 0.13f),
                Offset(centerX, tipY),
                strokeWidth,
                StrokeCap.Round
            )
        }
    }
}
