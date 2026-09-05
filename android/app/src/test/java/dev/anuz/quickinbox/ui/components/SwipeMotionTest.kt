package dev.anuz.quickinbox.ui.components

import org.junit.Assert.*
import org.junit.Test

class SwipeMotionTest {
    @Test fun neighborsFollowBothDirectionsWithoutExceedingTheLimit() {
        for (offset in listOf(-10000f, -80f, 0f, 80f, 10000f)) {
            val near = neighborPull(1, offset, 12f)
            val far = neighborPull(2, offset, 12f)
            assertTrue(kotlin.math.abs(near) <= 12f)
            assertTrue(kotlin.math.abs(far) <= kotlin.math.abs(near))
            assertTrue(near * offset >= 0f)
            assertEquals(0f, neighborPull(3, offset, 12f), 0f)
            assertEquals(0f, neighborPull(0, offset, 12f), 0f)
        }
    }

    @Test fun disposingAnOldRowDoesNotClearTheNewSwipe() {
        val motion = StickySwipeMotion()
        motion.update(1, 80f)
        motion.update(2, -100f)
        motion.update(1, 0f)
        assertEquals(2, motion.activeIndex)
        assertEquals(-100f, motion.displacement, 0f)
    }

    @Test fun settlingOrRemovingTheActiveRowReleasesItsNeighbors() {
        val motion = StickySwipeMotion()
        motion.update(3, 100f)
        motion.update(3, 0f)
        assertEquals(-1, motion.activeIndex)
        assertEquals(0f, motion.displacement, 0f)
    }

    @Test fun thresholdIsThumbSizedOnWideScreensAndFitsNarrowScreens() {
        assertEquals(112f, swipeTriggerDistance(400f, 1f), 0.001f)
        assertEquals(112f, swipeTriggerDistance(1200f, 1f), 0.001f)
        assertEquals(72f, swipeTriggerDistance(200f, 1f), 0.001f)
        assertEquals(224f, swipeTriggerDistance(800f, 2f), 0.001f)
    }

    @Test fun iconFinishesBeforeActionBecomesArmed() {
        assertEquals(0f, swipeAnimationProgress(0f), 0f)
        assertEquals(1f, swipeAnimationProgress(0.85f), 0f)
        assertFalse(swipeActionArmed(0.85f))
        assertFalse(swipeActionArmed(0.999f))
        assertTrue(swipeActionArmed(1f))
        assertTrue(swipeActionArmed(-1f))
        assertEquals(1f, swipeAnimationProgress(1.5f), 0f)
    }

    @Test fun reversingTheGestureReversesProgressAndDisarmsTheAction() {
        assertTrue(swipeActionArmed(1.1f))
        assertFalse(swipeActionArmed(0.9f))
        val forward = listOf(0f, 0.3f, 0.6f, 0.85f).map(::swipeAnimationProgress)
        val reverse = listOf(0.85f, 0.6f, 0.3f, 0f).map(::swipeAnimationProgress)
        assertEquals(forward.reversed(), reverse)
    }
    @Test fun holdingPastThresholdThenRetreatingCancelsOnRelease() {
        val drag = listOf(0f, 80f, 130f, 130f, 130f, 120f, 105f, 80f)
        assertEquals(0, swipeReleaseDirection(drag.last(), 112f, true))
        assertEquals(0, swipeReleaseDirection(-drag.last(), 112f, true))
        assertEquals(1, swipeReleaseDirection(130f, 112f, true))
        assertEquals(-1, swipeReleaseDirection(-130f, 112f, true))
        assertEquals(0, swipeReleaseDirection(130f, 112f, false))
    }
}
