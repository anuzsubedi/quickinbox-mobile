package dev.anuz.quickinbox

import dev.anuz.quickinbox.domain.pairingHost
import dev.anuz.quickinbox.domain.validatePairing
import dev.anuz.quickinbox.domain.validatePayload
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PairingValidationTest {
    private val code = "abcdefghijklmnopqrstuv"

    @Test
    fun validatesAndNormalizesSecurePairing() {
        val pairing = validatePairing(" HTTPS://Example.COM/ ", code)

        assertEquals("https://example.com", pairing?.origin)
        assertEquals(code, pairing?.code)
        assertEquals("example.com", pairingHost(pairing!!.origin))
    }

    @Test
    fun rejectsPathsCredentialsAndMalformedCodes() {
        assertNull(validatePairing("https://example.com/inbox", code))
        assertNull(validatePairing("https://user:pass@example.com", code))
        assertNull(validatePairing("https://example.com", "too-short"))
    }

    @Test
    fun payloadRequiresExactVersionedShape() {
        val valid = """{"version":1,"origin":"https://example.com","code":"$code"}"""
        val extra = """{"version":1,"origin":"https://example.com","code":"$code","extra":true}"""

        assertEquals("https://example.com", validatePayload(valid)?.origin)
        assertNull(validatePayload(extra))
        assertNull(validatePayload(valid.replace("\"version\":1", "\"version\":2")))
    }
}
