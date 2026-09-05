package dev.anuz.quickinbox.ui.components.swipeicons

internal data class EnvelopeTransferPose(val flap: Float, val letterY: Float)

/** Open first, then withdraw the letter; unread traverses this same sequence backwards. */
internal fun envelopeTransferPose(progress: Float): EnvelopeTransferPose = EnvelopeTransferPose(
    flap = phase(progress, 0f, 0.3f),
    letterY = 15f - 13f * phase(progress, 0.25f, 1f)
)

internal data class BinTransferPose(val lid: Float, val fileY: Float, val fileAngle: Float)

/** Lift the lid, insert the file completely, then close. */
internal fun binTransferPose(progress: Float): BinTransferPose {
    val drop = phase(progress, 0.25f, 0.75f)
    return BinTransferPose(
        lid = phase(progress, 0f, 0.2f) * (1f - phase(progress, 0.8f, 1f)),
        fileY = 1.5f + 10.5f * drop,
        fileAngle = -8f * (1f - drop)
    )
}

internal fun archiveArrowTravel(progress: Float): Float = 4f * phase(progress)
