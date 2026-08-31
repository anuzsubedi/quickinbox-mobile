package dev.anuz.quickinbox.data

import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import com.google.gson.reflect.TypeToken
import dev.anuz.quickinbox.domain.AddressesResponse
import dev.anuz.quickinbox.domain.ComposeMessage
import dev.anuz.quickinbox.domain.Credential
import dev.anuz.quickinbox.domain.CurrentUserResponse
import dev.anuz.quickinbox.domain.DevicesResponse
import dev.anuz.quickinbox.domain.DownloadedAttachment
import dev.anuz.quickinbox.domain.DraftResponse
import dev.anuz.quickinbox.domain.EmailAttachment
import dev.anuz.quickinbox.domain.MailAction
import dev.anuz.quickinbox.domain.MailActionBody
import dev.anuz.quickinbox.domain.MailActionResponse
import dev.anuz.quickinbox.domain.MailAddress
import dev.anuz.quickinbox.domain.MailboxFilters
import dev.anuz.quickinbox.domain.MailboxKind
import dev.anuz.quickinbox.domain.MailboxPage
import dev.anuz.quickinbox.domain.MutationResponse
import dev.anuz.quickinbox.domain.PAIRING_CODE_LENGTH
import dev.anuz.quickinbox.domain.PairingRequest
import dev.anuz.quickinbox.domain.PairingResponse
import dev.anuz.quickinbox.domain.ReplyMessage
import dev.anuz.quickinbox.domain.ForwardMessage
import dev.anuz.quickinbox.domain.SendMessageResponse
import dev.anuz.quickinbox.domain.ServerErrorBody
import dev.anuz.quickinbox.domain.SignatureResponse
import dev.anuz.quickinbox.domain.SignatureUpdateRequest
import dev.anuz.quickinbox.domain.SignatureValueResponse
import dev.anuz.quickinbox.domain.ThreadDetail
import dev.anuz.quickinbox.domain.ThreadFlags
import dev.anuz.quickinbox.domain.User
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.File
import java.io.IOException
import java.util.Date
import java.util.UUID
import java.util.concurrent.TimeUnit

class QuickInboxApi(
    private val gson: Gson,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .callTimeout(30, TimeUnit.SECONDS)
        .build()
) {
    @Volatile
    var credential: Credential? = null
        private set

    @Volatile
    var onUnauthorized: (() -> Unit)? = null

    @Synchronized
    fun install(value: Credential) {
        credential = value
    }

    @Synchronized
    fun clearCredential() {
        credential = null
    }

    fun pair(origin: String, code: String, deviceName: String): Credential {
        val validatedOrigin = OriginValidator.validate(origin)
        val clean = code.trim()
        if (clean.length != PAIRING_CODE_LENGTH ||
            clean.any { !it.isLetterOrDigit() && it != '_' && it != '-' }
        ) {
            throw ApiError.InvalidPairingPayload
        }
        val body = PairingRequest(code = clean, deviceName = deviceName.take(64))
        val response: PairingResponse = request(
            origin = validatedOrigin,
            path = listOf("api", "auth", "pair"),
            method = "POST",
            body = body,
            authenticated = false
        )
        val expiresAt = response.expiresAt
        if (response.token.isEmpty() || expiresAt == null || !expiresAt.after(Date())) {
            throw ApiError.InvalidResponse
        }
        return Credential(origin = validatedOrigin, token = response.token, expiresAt = expiresAt)
    }

    fun currentUser(): User =
        authenticatedRequest<CurrentUserResponse>(listOf("api", "auth", "me")).user

    fun listThreads(
        mailbox: MailboxKind = MailboxKind.Inbox,
        page: Int = 1,
        filters: MailboxFilters = MailboxFilters()
    ): MailboxPage {
        val query = mutableListOf(
            "view" to mailbox.apiValue,
            "page" to maxOf(1, page).toString()
        )
        val trimmed = filters.query.trim()
        if (trimmed.isNotEmpty()) query += "q" to trimmed
        if (filters.unreadOnly) query += "unread" to "1"
        if (filters.starredOnly) query += "starred" to "1"
        if (filters.attachmentsOnly) query += "attachments" to "1"
        filters.domainId?.let { query += "domain" to it }
        return authenticatedRequest(listOf("api", "mail"), query = query)
    }

    fun thread(id: String): ThreadDetail = authenticatedRequest(listOf("api", "mail", id))

    fun draft(id: String) = authenticatedRequest<DraftResponse>(listOf("api", "drafts", id)).draft

    fun send(message: ComposeMessage): SendMessageResponse =
        authenticatedRequest(listOf("api", "mail"), method = "POST", body = message)

    fun reply(id: String, message: ReplyMessage): SendMessageResponse =
        authenticatedRequest(listOf("api", "mail", id), method = "POST", body = message)

    fun forwardMessage(id: String, message: ForwardMessage): SendMessageResponse =
        authenticatedRequest(listOf("api", "mail", id, "forward"), method = "POST", body = message)

    fun forwardThread(threadId: String, message: ForwardMessage): SendMessageResponse =
        authenticatedRequest(
            listOf("api", "mail", "thread", threadId, "forward"),
            method = "POST",
            body = message
        )

    fun updateThread(id: String, flags: ThreadFlags): MutationResponse =
        authenticatedRequest(listOf("api", "mail", id), method = "PATCH", body = flags)

    fun perform(action: MailAction, ids: List<String> = emptyList()): MailActionResponse =
        authenticatedRequest(
            listOf("api", "mail", "actions"),
            method = "POST",
            body = MailActionBody(action.apiValue, ids)
        )

    fun deletePermanently(id: String): MutationResponse =
        authenticatedRequest(listOf("api", "mail", id), method = "DELETE")

    fun addresses(): List<MailAddress> =
        authenticatedRequest<AddressesResponse>(listOf("api", "addresses")).addresses

    fun updateSignature(signature: String): String =
        authenticatedRequest<SignatureResponse>(
            listOf("api", "settings", "signature"),
            method = "PATCH",
            body = SignatureUpdateRequest(signature)
        ).signature

    fun signature(): String =
        authenticatedRequest<SignatureValueResponse>(listOf("api", "settings", "signature")).signature

    fun devices() = authenticatedRequest<DevicesResponse>(listOf("api", "devices")).devices

    fun revokeDevice(id: String): MutationResponse =
        authenticatedRequest(listOf("api", "devices", id), method = "DELETE")

    fun logout(credentialStore: CredentialStore, revokeCurrentDevice: Boolean = true) {
        var revocationError: Exception? = null
        if (revokeCurrentDevice && credential != null) {
            try {
                authenticatedRequest<MutationResponse>(listOf("api", "auth", "session"), method = "DELETE")
            } catch (error: Exception) {
                revocationError = error
            }
        }
        credential = null
        credentialStore.delete()
        if (revocationError != null) throw revocationError
    }

    fun downloadAttachment(
        emailId: String,
        attachment: EmailAttachment,
        directory: File
    ): DownloadedAttachment {
        if (!directory.exists() && !directory.mkdirs()) {
            throw ApiError.Transport("Attachment storage is unavailable")
        }
        pruneAttachmentCache(directory)
        val request = makeRequest(
            origin = authenticatedOrigin(),
            path = listOf("api", "mail", emailId, "attachments", attachment.id),
            query = listOf("download" to "1"),
            method = "GET",
            body = null,
            authenticated = true
        )
        var folder: File? = null
        try {
            client.newCall(request).execute().use { response ->
                validate(response)
                val filename = safeFilename(
                    contentDispositionFilename(response.header("Content-Disposition"))
                        ?: attachment.filename
                )
                folder = File(directory, UUID.randomUUID().toString())
                if (folder?.mkdirs() != true) throw IOException("Attachment storage is unavailable")
                val destination = File(folder, filename)
                response.body?.byteStream()?.use { input ->
                    destination.outputStream().use { output -> input.copyTo(output) }
                } ?: throw ApiError.InvalidResponse
                return DownloadedAttachment(
                    file = destination,
                    filename = filename,
                    contentType = response.header("Content-Type") ?: attachment.contentType
                )
            }
        } catch (error: ApiError) {
            folder?.deleteRecursively()
            throw error
        } catch (error: IOException) {
            folder?.deleteRecursively()
            throw ApiError.Transport(error.localizedMessage ?: "Network error")
        }
    }

    private inline fun <reified T> authenticatedRequest(
        path: List<String>,
        query: List<Pair<String, String>> = emptyList(),
        method: String = "GET",
        body: Any? = null
    ): T = request(authenticatedOrigin(), path, query, method, body, authenticated = true)

    private inline fun <reified T> request(
        origin: String,
        path: List<String>,
        query: List<Pair<String, String>> = emptyList(),
        method: String,
        body: Any?,
        authenticated: Boolean
    ): T {
        val httpRequest = makeRequest(origin, path, query, method, body, authenticated)
        try {
            client.newCall(httpRequest).execute().use { response ->
                val payload = response.body?.string().orEmpty()
                validate(response, payload)
                return try {
                    gson.fromJson<T>(payload, object : TypeToken<T>() {}.type)
                        ?: throw ApiError.Decoding
                } catch (_: JsonSyntaxException) {
                    throw ApiError.Decoding
                } catch (_: ClassCastException) {
                    throw ApiError.Decoding
                }
            }
        } catch (error: ApiError) {
            throw error
        } catch (error: IOException) {
            throw ApiError.Transport(error.localizedMessage ?: "Network error")
        }
    }

    private fun makeRequest(
        origin: String,
        path: List<String>,
        query: List<Pair<String, String>>,
        method: String,
        body: Any?,
        authenticated: Boolean
    ): Request {
        val parsed = try {
            origin.toHttpUrl()
        } catch (_: Exception) {
            throw ApiError.InvalidRequest
        }
        val builder = parsed.newBuilder()
        path.forEach { builder.addPathSegment(it) }
        query.forEach { (name, value) -> builder.addQueryParameter(name, value) }
        val json = body?.let { gson.toJson(it) }
        val media = "application/json; charset=utf-8".toMediaType()
        val requestBody = when {
            method == "GET" || method == "DELETE" && json == null -> null
            json != null -> json.toRequestBody(media)
            method == "POST" || method == "PATCH" || method == "PUT" || method == "DELETE" -> {
                ByteArray(0).toRequestBody(null)
            }
            else -> null
        }
        return Request.Builder()
            .url(builder.build())
            .method(method, requestBody)
            .header("Accept", "application/json")
            .apply {
                if (json != null) header("Content-Type", "application/json")
                if (authenticated) {
                    val current = credential
                    if (current == null || current.isExpired) {
                        onUnauthorized?.invoke()
                        throw ApiError.Unauthorized
                    }
                    header("Authorization", "Bearer ${current.token}")
                }
            }
            .build()
    }

    private fun authenticatedOrigin(): String {
        val current = credential
        if (current == null || current.isExpired) {
            onUnauthorized?.invoke()
            throw ApiError.Unauthorized
        }
        return current.origin
    }

    private fun validate(response: Response, data: String? = null) {
        if (response.code in 200..299) return
        val message = data?.let { payload ->
            try {
                gson.fromJson(payload, ServerErrorBody::class.java)?.error?.takeIf { it.isNotBlank() }
            } catch (_: Exception) {
                null
            }
        } ?: response.message.ifBlank { "Request failed" }
        val error: ApiError = when (response.code) {
            401 -> {
                onUnauthorized?.invoke()
                ApiError.Unauthorized
            }
            403 -> ApiError.Forbidden(message)
            404 -> ApiError.NotFound(message)
            429 -> ApiError.RateLimited(response.header("Retry-After")?.toLongOrNull())
            else -> ApiError.Server(response.code, message)
        }
        throw error
    }

    private fun contentDispositionFilename(value: String?): String? {
        if (value.isNullOrBlank()) return null
        val match = Regex("""filename="([^"]+)"""").find(value) ?: return null
        return match.groupValues[1]
    }

    private fun safeFilename(value: String): String {
        val filename = value.replace("\\", "/").substringAfterLast('/')
        return if (filename.isEmpty() || filename == "." || filename == "..") "attachment" else filename
    }
}

internal const val ATTACHMENT_CACHE_MAX_AGE_MS = 24L * 60L * 60L * 1000L
internal const val ATTACHMENT_CACHE_MAX_FOLDERS = 24

internal fun pruneAttachmentCache(directory: File, nowMillis: Long = System.currentTimeMillis()) {
    val folders = directory.listFiles()?.filter { it.isDirectory }
        ?.sortedByDescending { it.lastModified() }
        .orEmpty()
    folders.forEachIndexed { index, folder ->
        val age = (nowMillis - folder.lastModified()).coerceAtLeast(0L)
        if (age > ATTACHMENT_CACHE_MAX_AGE_MS || index >= ATTACHMENT_CACHE_MAX_FOLDERS) {
            runCatching { folder.deleteRecursively() }
        }
    }
}
