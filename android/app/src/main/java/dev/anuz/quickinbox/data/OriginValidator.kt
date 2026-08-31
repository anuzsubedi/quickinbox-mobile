package dev.anuz.quickinbox.data

import dev.anuz.quickinbox.BuildConfig
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

object OriginValidator {
    fun validate(rawValue: String): String {
        val value = rawValue.trim()
        if (value.isEmpty()) throw ApiError.InvalidOrigin("Enter your QuickInbox server URL.")

        val uri = value.toHttpUrlOrNull()
            ?: throw ApiError.InvalidOrigin("The server URL must include a valid host.")
        if (uri.username.isNotEmpty() || uri.password.isNotEmpty()) {
            throw ApiError.InvalidOrigin("The server URL cannot contain credentials.")
        }
        if (uri.query != null || uri.fragment != null) {
            throw ApiError.InvalidOrigin("Use only the QuickInbox server origin, without a query or fragment.")
        }
        if (uri.encodedPath != "/") {
            throw ApiError.InvalidOrigin("Use only the QuickInbox server origin, without a path.")
        }
        val host = uri.host.lowercase()

        val scheme = uri.scheme.lowercase()
        val isLocalHttp = BuildConfig.DEBUG &&
            scheme == "http" &&
            host in setOf("localhost", "127.0.0.1", "::1")
        if (scheme != "https" && !isLocalHttp) {
            throw ApiError.InvalidOrigin("QuickInbox requires a secure HTTPS server URL.")
        }

        return uri.toString().trimEnd('/')
    }
}
