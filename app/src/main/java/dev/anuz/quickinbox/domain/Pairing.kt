package dev.anuz.quickinbox.domain

import android.net.Uri
import org.json.JSONObject

const val PAIRING_CODE_LENGTH = 22

data class Pairing(val origin: String, val code: String)

fun validatePayload(value: String): Pairing? = try {
    val json = JSONObject(value)
    if (json.length() != 3 || json.optInt("version") != 1) null
    else validatePairing(json.getString("origin"), json.getString("code"))
} catch (_: Exception) {
    null
}

fun validatePairing(origin: String, code: String): Pairing? {
    val uri = Uri.parse(origin.trim())
    val clean = code.trim()
    return if (
        (uri.scheme == "https" || uri.scheme == "http") && !uri.host.isNullOrBlank() &&
        clean.length == PAIRING_CODE_LENGTH && clean.all { it.isLetterOrDigit() || it == '_' || it == '-' }
    ) Pairing(uri.toString(), clean) else null
}
