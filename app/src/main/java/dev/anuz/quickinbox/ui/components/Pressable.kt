package dev.anuz.quickinbox.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.unit.dp

/** Opacity of the tonal scrim applied while a [Pressable] surface is pressed. */
private const val TonalPressedAlpha = 0.08f

/**
 * A minimal press primitive. It tracks press through [MutableInteractionSource]
 * and applies an immediate tonal scrim (8%) instead of the default material ripple, so surfaces
 * feel responsive without a ripple halo. The surface is clipped to [shape]; give it a background
 * (or leave it transparent) inside [content]. Focus, role, click label, and any selected/toggle
 * semantics are supplied by the caller through [modifier].
 */
@Composable
fun Pressable(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    role: Role? = null,
    onClickLabel: String? = null,
    selectedState: Boolean? = null,
    checkedState: Boolean? = null,
    stateDescription: String? = null,
    shape: Shape = RectangleShape,
    tonalColor: Color = MaterialTheme.colorScheme.onSurface,
    interactionSource: MutableInteractionSource = remember { MutableInteractionSource() },
    content: @Composable BoxScope.() -> Unit
) {
    val pressed by interactionSource.collectIsPressedAsState()
    Box(
        modifier = modifier
            .clip(shape)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = role,
                onClickLabel = onClickLabel,
                onClick = onClick
            )
            .semantics {
                selectedState?.let { selected = it }
                checkedState?.let {
                    toggleableState = if (it) ToggleableState.On else ToggleableState.Off
                }
                stateDescription?.let { this.stateDescription = it }
            }
            .drawWithContent {
                drawContent()
                if (pressed) drawRect(tonalColor.copy(alpha = TonalPressedAlpha))
            }
    ) {
        content()
    }
}

/**
 * A decorative 24×3 dp registration mark — a short ruled bar that anchors selected state,
 * echoing the registration marks of a print layout.
 */
@Composable
fun RegistrationMark(
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary
) {
    Box(
        modifier = modifier
            .size(width = 24.dp, height = 3.dp)
            .clip(CircleShape)
            .background(color)
    )
}
