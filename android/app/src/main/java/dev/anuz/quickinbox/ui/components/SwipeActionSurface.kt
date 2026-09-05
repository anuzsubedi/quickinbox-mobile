package dev.anuz.quickinbox.ui.components

import androidx.compose.animation.core.animate
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.data.SwipeControl
import dev.anuz.quickinbox.domain.MailAction
import kotlin.math.abs

internal data class SwipeActionSpec(val control: SwipeControl, val action: MailAction, val label: String) {
    val destructive get() = action == MailAction.Trash || action == MailAction.Delete
}

/** A small, bounded pull on the two closest rows; ownership prevents recycled rows clearing a new drag. */
@Stable
internal class StickySwipeMotion {
    var activeIndex by mutableIntStateOf(-1)
        private set
    var displacement by mutableFloatStateOf(0f)
        private set
    fun update(index: Int, offset: Float) {
        if (abs(offset) > 0.5f) {
            activeIndex = index
            displacement = offset
        } else if (activeIndex == index) {
            activeIndex = -1
            displacement = 0f
        }
    }
}

internal fun neighborPull(distance: Int, offset: Float, limit: Float): Float =
    (offset * when (distance) { 1 -> 0.06f; 2 -> 0.02f; else -> 0f }).coerceIn(-limit, limit)

/** Both the mailbox and settings preview use this exact gesture, threshold and feedback. */
@Suppress("DEPRECATION") // Veto settling so read/star actions and cancelled delete confirmations return the row.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SwipeActionSurface(
    startAction: SwipeActionSpec?,
    endAction: SwipeActionSpec?,
    enabled: Boolean,
    index: Int,
    motion: StickySwipeMotion,
    modifier: Modifier = Modifier,
    previewRequest: Int = 0,
    onAction: (MailAction) -> Unit,
    content: @Composable () -> Unit
) {
    val currentStart by rememberUpdatedState(startAction)
    val currentEnd by rememberUpdatedState(endAction)
    val currentAction by rememberUpdatedState(onAction)
    val currentEnabled by rememberUpdatedState(enabled)
    var width by remember { mutableIntStateOf(1) }
    val density = LocalDensity.current
    val triggerDistance = swipeTriggerDistance(width.toFloat(), density.density)
    val currentTrigger by rememberUpdatedState(triggerDistance)
    var demoOffset by remember { mutableFloatStateOf(0f) }
    var playing by remember { mutableStateOf(false) }
    var pending by remember { mutableStateOf<SwipeActionSpec?>(null) }
    val haptics = rememberQuickInboxHaptics()
    val stateReference = remember { mutableStateOf<SwipeToDismissBoxState?>(null) }
    val state = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            val action = when (value) {
                SwipeToDismissBoxValue.StartToEnd -> currentStart
                SwipeToDismissBoxValue.EndToStart -> currentEnd
                else -> null
            }
            val releasedOffset = stateReference.value?.let { runCatching { it.requireOffset() }.getOrDefault(0f) } ?: 0f
            val releaseDirection = swipeReleaseDirection(releasedOffset, currentTrigger, currentEnabled)
            val expectedDirection = if (value == SwipeToDismissBoxValue.EndToStart) -1 else 1
            if (action != null && pending == null && !playing && releaseDirection == expectedDirection) {
                demoOffset = releasedOffset
                pending = action
            }
            false
        },
        positionalThreshold = { swipeTriggerDistance(it, density.density) }
    )
    // Offset, unlike transition progress, is continuous when the dismiss target changes.
    val nativeOffset = runCatching { state.requireOffset() }.getOrDefault(0f)
    val overriding = playing || pending != null
    val offset = if (overriding) demoOffset else nativeOffset
    val fraction = (abs(offset) / width.coerceAtLeast(1)).coerceIn(0f, 1f)
    val reveal = abs(offset) / triggerDistance
    val armed = pending != null || swipeActionArmed(reveal)
    val iconProgress = if (pending != null) 1f else swipeAnimationProgress(reveal)
    // Hold the depicted action through its return animation when read/star state updates.
    val gestureAction = remember(offset > 0f, offset < 0f, startAction?.control, endAction?.control) {
        if (offset >= 0f) startAction else endAction
    }
    val action = pending ?: gestureAction
    LaunchedEffect(armed) { if (armed && enabled) haptics.selectionChanged() }
    SideEffect { stateReference.value = state; motion.update(index, offset) }
    DisposableEffect(motion, index) { onDispose { motion.update(index, 0f) } }
    LaunchedEffect(enabled) { if (!enabled && pending == null) state.reset() }
    LaunchedEffect(pending) {
        val chosen = pending ?: return@LaunchedEffect
        try {
            completeSwipeFeedback(
                stillEnabled = { currentEnabled },
                dispatch = { currentAction(chosen.action) },
                returnToRest = {
                    state.snapTo(SwipeToDismissBoxValue.Settled)
                    animate(demoOffset, 0f, animationSpec = tween(170)) { value, _ -> demoOffset = value }
                }
            )
        } finally {
            demoOffset = 0f
            pending = null
        }
    }
    LaunchedEffect(previewRequest) {
        if (previewRequest == 0 || pending != null) return@LaunchedEffect
        val spec = if (previewRequest > 0) currentStart else currentEnd
        if (spec == null) return@LaunchedEffect
        state.reset()
        playing = true
        try {
            val target = triggerDistance * 1.12f * if (previewRequest > 0) 1f else -1f
            animate(0f, target, animationSpec = tween(420)) { value, _ -> demoOffset = value }
            pending = spec // Real gestures and replay now share the entire completion sequence.
        } finally {
            playing = false
            if (pending == null) demoOffset = 0f
        }
    }
    val limit = with(LocalDensity.current) { 8.dp.toPx() }
    val neighbor by animateFloatAsState(
        neighborPull(abs(index - motion.activeIndex), motion.displacement, limit),
        spring(dampingRatio = 0.72f, stiffness = 550f), label = "Neighbor pull"
    )
    val shape = RoundedCornerShape((fraction * 40f).coerceAtMost(20f).dp)
    Box(modifier.onSizeChanged { width = it.width }.graphicsLayer {
        translationX = if (motion.activeIndex == index) 0f else neighbor
    }.semantics {
        if (enabled && !overriding) customActions = listOfNotNull(startAction, endAction).distinctBy { it.action }.map { spec ->
            CustomAccessibilityAction(spec.label) { onAction(spec.action); true }
        }
    }) {
        SwipeToDismissBox(
            state = state,
            gesturesEnabled = enabled && !overriding,
            enableDismissFromStartToEnd = enabled && startAction != null,
            enableDismissFromEndToStart = enabled && endAction != null,
            backgroundContent = {
                val colors = MaterialTheme.colorScheme
                val container = if (action?.destructive == true) colors.errorContainer else colors.primaryContainer
                val destructive = action?.destructive == true
                val activeColor = if (destructive) colors.error else colors.primary
                val activeInk = if (destructive) colors.onError else colors.onPrimary
                val ink = if (armed) activeInk else if (destructive) colors.onErrorContainer else colors.onPrimaryContainer
                Surface(
                    Modifier.fillMaxSize().padding(horizontal = 8.dp),
                    shape = MaterialTheme.shapes.large,
                    color = if (armed) activeColor else container
                ) {
                    if (action != null) Box(
                        Modifier.fillMaxSize().padding(horizontal = 20.dp),
                        contentAlignment = if (offset > 0f) AbsoluteAlignment.CenterLeft else AbsoluteAlignment.CenterRight
                    ) {
                        Surface(
                            modifier = Modifier.size(48.dp).graphicsLayer {
                                val arrival = (reveal / 0.45f).coerceIn(0f, 1f)
                                val pop = 0.035f * kotlin.math.sin(Math.PI * iconProgress).toFloat()
                                scaleX = 0.82f + 0.18f * arrival + pop
                                scaleY = scaleX
                                alpha = arrival
                            },
                            shape = RoundedCornerShape(16.dp),
                            color = androidx.compose.ui.graphics.Color.Transparent
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                SwipeControlIcon(
                                    control = action.control,
                                    progress = iconProgress,
                                    color = ink,
                                    modifier = Modifier.size(30.dp),
                                    resolvedAction = action.action
                                )
                            }
                        }
                    }
                }
            }
        ) {
            Box(Modifier.graphicsLayer { translationX = swipeContentCompensation(nativeOffset, demoOffset, overriding) }.clip(shape)) { content() }
        }
    }
}
