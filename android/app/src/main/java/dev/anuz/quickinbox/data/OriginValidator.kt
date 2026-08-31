package dev.anuz.quickinbox.data

import android.net.Uri
import dev.anuz.quickinbox.BuildConfig

object OriginValidator {
    fun validate(rawValue: String): String {
        val value = rawValue.trim()
        if (value.isEmpty()) throw ApiError.InvalidOrigin("Enter your QuickInbox server URL.")

        val uri = Uri.parse(value)
        if (!uri.userInfo.isNullOrEmpty()) {
            throw ApiError.InvalidOrigin("The server URL cannot contain credentials.")
        }
        if (!uri.query.isNullOrEmpty() || !uri.fragment.isNullOrEmpty()) {
            throw ApiError.InvalidOrigin("Use only the QuickInbox server origin, without a query or fragment.")
        }
        val path = uri.path.orEmpty()
        if (path.isNotEmpty() && path != "/") {
            throw ApiError.InvalidOrigin("Use only the QuickInbox server origin, without a path.")
        }
        val host = uri.host?.lowercase().orEmpty()
        if (host.isEmpty()) throw ApiError.InvalidOrigin("The server URL must include a host.")

        val scheme = uri.scheme?.lowercase()
        val isLocalHttp = BuildConfig.DEBUG &&
            scheme == "http" &&
            host in setOf("localhost", "127.0.0.1", "::1")
        if (scheme != "https" && !isLocalHttp) {
            throw ApiError.InvalidOrigin("QuickInbox requires a secure HTTPS server URL.")
        }

        return Uri.Builder()
            .scheme(scheme)
            .encodedAuthority(host + (if (uri.port != -1) ":${uri.port}" else ""))
            .build()
            .toString()
            .trimEnd('/')
    }
}
