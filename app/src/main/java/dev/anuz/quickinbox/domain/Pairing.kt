package dev.anuz.quickinbox.domain

import android.net.Uri
import dev.anuz.quickinbox.data.ApiError
import dev.anuz.quickinbox.data.OriginValidator
import org.json.JSONObject

const val PAIRING_CODE_LENGTH = 22
private const val MAXIMUM_PAYLOAD_BYTES = 2048

data class Pairing(val origin: String, val code: String)

fun validatePayload(value: String): Pairing? {
    val bytes = value.toByteArray(Charsets.UTF_8)
    if (bytes.isEmpty() || bytes.size > MAXIMUM_PAYLOAD_BYTES) return null
    return try {
        val json = JSONObject(value)
        val keys = json.keys().asSequence().toSet()
        if (keys != setOf("version", "origin", "code") || json.optInt("version") != 1) null
        else validatePairing(json.getString("origin"), json.getString("code"))
    } catch (_: Exception) {
        null
    }
}

fun validatePairing(origin: String, code: String): Pairing? = try {
    val normalized = OriginValidator.validate(origin)
    val clean = code.trim()
    if (clean.length == PAIRING_CODE_LENGTH &&
        clean.all { it.isLetterOrDigit() || it == '_' || it == '-' }
    ) Pairing(normalized, clean) else null
} catch (_: ApiError.InvalidOrigin) {
    null
} catch (_: Exception) {
    null
}

fun pairingHost(origin: String): String = Uri.parse(origin).host ?: origin
