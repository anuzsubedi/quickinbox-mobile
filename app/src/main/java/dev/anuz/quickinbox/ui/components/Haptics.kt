package dev.anuz.quickinbox.ui.components

import android.view.HapticFeedbackConstants
import android.view.View
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView

/**
 * Semantic haptic helpers for QuickInbox. All feedback is dispatched through the host view's
 * [HapticFeedback], which does not pass `FLAG_IGNORE_GLOBAL_SETTING`, so every event honors the
 * user's system "touch feedback" accessibility setting and never vibrates when the user has
 * disabled haptics globally.
 *
 * Use [rememberQuickInboxHaptics] to obtain an instance inside composition.
 */
class QuickInboxHaptics internal constructor(
    private val feedback: HapticFeedback,
    private val view: View
) {
    /** A light tick for taps and low-emphasis interactions. */
    fun tap() {
        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    }

    /** Standard long-press confirmation that the press has registered. */
    fun longPress() {
        feedback.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    /** A light tick when a selection or handle movement changes. */
    fun selectionChanged() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            view.performHapticFeedback(HapticFeedbackConstants.SEGMENT_TICK)
        } else {
            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        }
    }

    /** Positive confirmation of a completed action. */
    fun confirm() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        } else {
            feedback.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }

    /** Negative confirmation of a rejected or failed action. */
    fun reject() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            view.performHapticFeedback(HapticFeedbackConstants.REJECT)
        } else {
            feedback.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }
}

/** Remembers a [QuickInboxHaptics] bound to the current [HapticFeedback] instance. */
@Composable
fun rememberQuickInboxHaptics(): QuickInboxHaptics {
    val feedback = LocalHapticFeedback.current
    val view = LocalView.current
    return remember(feedback, view) { QuickInboxHaptics(feedback, view) }
}
