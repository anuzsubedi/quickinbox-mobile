package dev.anuz.quickinbox.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.LinearEasing

/**
 * Minimal, cohesive motion tokens for QuickInbox. Durations are intentionally short and
 * easing curves are semantic rather than decorative. No motion should be added unless it
 * communicates hierarchy or state; these tokens keep that motion consistent and restrained.
 */
object QuickInboxMotion {
    /** Quick emphasis feedback such as ripples or pressed states. */
    const val DurationShort = 150

    /** Default transition for surface changes and state swaps. */
    const val DurationMedium = 250

    /** Slower transitions reserved for larger layout movements. */
    const val DurationLong = 400

    /** Standard easing for most transitions: quick start, gentle settle. */
    val Standard: Easing = CubicBezierEasing(0.2f, 0.0f, 0.0f, 1.0f)

    /** Emphasized easing for entrances and prominent transitions. */
    val Emphasized: Easing = CubicBezierEasing(0.4f, 0.0f, 0.2f, 1.0f)

    /** Decelerate easing for exits and dismissal. */
    val Decelerate: Easing = CubicBezierEasing(0.0f, 0.0f, 0.0f, 1.0f)

    /** Constant-rate easing for indeterminate or progress-style motion. */
    val Linear: Easing = LinearEasing
}
