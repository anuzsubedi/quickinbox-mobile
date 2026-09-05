package dev.anuz.quickinbox.ui.components.swipeicons

import org.junit.Assert.*
import org.junit.Test

class SwipeIconPhaseTest {
    @Test fun allUsedMotionStagesHaveStableClampedEndpoints() {
        for ((start, end) in listOf(0f to 1f, 0f to 0.8f, 0.65f to 1f, 0f to 0.7f,
            0.6f to 1f, 0f to 0.75f, 0.1f to 0.85f, 0f to 0.9f, 0.15f to 0.9f)) {
            assertEquals(0f, phase(-0.1f, start, end), 0f)
            assertEquals(0f, phase(start, start, end), 0f)
            assertEquals(1f, phase(end, start, end), 0f)
            assertEquals(1f, phase(1.1f, start, end), 0f)
        }
    }

    @Test fun iconMotionFollowsTheFingerContinuouslyInBothDirections() {
        val samples = (0..100).map { phase(it / 100f) }
        assertTrue(samples.zipWithNext().all { (a, b) -> b >= a && b - a < 0.02f })
        assertEquals(samples.reversed(), (100 downTo 0).map { phase(it / 100f) })
    }
}
