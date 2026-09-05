package dev.anuz.quickinbox.ui.components.swipeicons

import org.junit.Assert.*
import org.junit.Test

class TransferMotionTest {
    @Test fun envelopeOpensBeforeTheLetterEmergesAndCanReverseExactly() {
        assertEquals(0f, envelopeTransferPose(0f).flap, 0f)
        // The letter starts below the deepest part of the V-shaped pocket, including its stroke.
        assertTrue(envelopeTransferPose(0.2f).letterY - 0.9f > 14f)
        assertEquals(1f, envelopeTransferPose(0.3f).flap, 0f)
        assertEquals(2f, envelopeTransferPose(1f).letterY, 0f)
        val poses = (0..100).map { envelopeTransferPose(it / 100f) }
        assertTrue(poses.zipWithNext().all { (a, b) -> a.letterY >= b.letterY })
        assertEquals(poses.reversed(), (100 downTo 0).map { envelopeTransferPose(it / 100f) })
    }

    @Test fun fileEntersOnlyAfterTheLidOpensAndClearsTheOpeningBeforeItCloses() {
        assertEquals(0f, binTransferPose(0f).lid, 0f)
        assertEquals(1f, binTransferPose(0.2f).lid, 0f)
        assertEquals(1.5f, binTransferPose(0.25f).fileY, 0f)
        assertEquals(1f, binTransferPose(0.75f).lid, 0f)
        assertTrue(binTransferPose(0.75f).fileY > 9f)
        assertEquals(0f, binTransferPose(1f).lid, 0f)
        val insertion = (0..100).map { binTransferPose(it / 100f) }
        assertEquals(insertion.reversed(), (100 downTo 0).map { binTransferPose(it / 100f) })
    }

    @Test fun archiveArrowTravelIsSmoothBoundedAndReversible() {
        val values = (0..100).map { archiveArrowTravel(it / 100f) }
        assertEquals(0f, values.first(), 0f)
        assertEquals(4f, values.last(), 0f)
        assertTrue(values.zipWithNext().all { (a, b) -> b >= a && b - a < 0.07f })
        assertEquals(values.reversed(), (100 downTo 0).map { archiveArrowTravel(it / 100f) })
    }
}
