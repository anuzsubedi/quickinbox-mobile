package dev.anuz.quickinbox.ui.components

/** Dispatch before any animation suspends: feedback never gates an accepted action. */
internal suspend fun completeSwipeFeedback(
    stillEnabled: () -> Boolean,
    dispatch: () -> Unit,
    returnToRest: suspend () -> Unit
) {
    if (stillEnabled()) dispatch()
    returnToRest()
}

/** Icons settle shortly before the release threshold, giving the ready cue a stable pose. */
internal fun swipeAnimationProgress(fraction: Float): Float =
    (kotlin.math.abs(fraction) / 0.85f).coerceIn(0f, 1f)

/** The parent already applies the native drag offset; only compensate for the difference. */
internal fun swipeContentCompensation(nativeOffset: Float, displayedOffset: Float, overriding: Boolean): Float =
    if (overriding) displayedOffset - nativeOffset else 0f

/** A consistent thumb travel on wide screens, proportional on narrow screens. */
internal fun swipeTriggerDistance(widthPx: Float, density: Float): Float =
    minOf(widthPx.coerceAtLeast(1f) * 0.36f, 112f * density.coerceAtLeast(0.1f))

internal const val SwipeActionThreshold = 1f
internal fun swipeActionArmed(fraction: Float): Boolean = kotlin.math.abs(fraction) >= SwipeActionThreshold

/** Called on release only. Crossing the threshold earlier in the drag is deliberately irrelevant. */
internal fun swipeReleaseDirection(offset: Float, threshold: Float, enabled: Boolean): Int = when {
    !enabled || threshold <= 0f || !offset.isFinite() || kotlin.math.abs(offset) < threshold -> 0
    offset > 0f -> 1
    else -> -1
}
