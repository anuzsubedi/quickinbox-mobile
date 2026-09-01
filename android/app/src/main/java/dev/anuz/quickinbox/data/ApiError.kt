package dev.anuz.quickinbox.data

import java.io.IOException
import java.net.UnknownHostException

sealed class ApiError(message: String) : Exception(message) {
    class InvalidOrigin(detail: String) : ApiError(detail)
    data object InvalidPairingPayload : ApiError("This QuickInbox pairing code is not supported.")
    data object InvalidRequest : ApiError("The request could not be created.")
    data object InvalidResponse : ApiError("The server returned an invalid response.")
    data object Unauthorized : ApiError("Your QuickInbox session is no longer valid.")
    class Forbidden(detail: String) : ApiError(detail)
    class NotFound(detail: String) : ApiError(detail)
    class RateLimited(retryAfterSeconds: Long?) : ApiError(
        if (retryAfterSeconds != null) "Too many attempts. Try again in ${retryAfterSeconds} seconds."
        else "Too many attempts. Try again later."
    )
    class Server(status: Int, detail: String) : ApiError(detail)
    class Transport(detail: String) : ApiError(detail)
    data object Decoding : ApiError("QuickInbox returned data this app could not read.")

    class CorruptCredential : Exception("The saved QuickInbox session was invalid and has been removed.")
}

internal fun IOException.toTransportError(
    host: String?,
    hasInternetAccess: (() -> Boolean)?
): ApiError.Transport {
    val online = hasInternetAccess?.let { check -> runCatching(check).getOrNull() }
    if (online == false) {
        return ApiError.Transport(
            "No internet connection. Connect to Wi-Fi or mobile data and try again."
        )
    }

    val server = host?.takeIf { it.isNotBlank() } ?: "your QuickInbox server"
    return if (this is UnknownHostException) {
        ApiError.Transport(
            "QuickInbox couldn’t find $server. Check the server address or DNS settings."
        )
    } else {
        ApiError.Transport(
            "QuickInbox can’t reach $server. The server may be unavailable. Try again later."
        )
    }
}
