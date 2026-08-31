package dev.anuz.quickinbox.data

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
