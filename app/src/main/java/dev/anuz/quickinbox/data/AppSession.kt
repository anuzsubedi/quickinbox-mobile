package dev.anuz.quickinbox.data

import dev.anuz.quickinbox.domain.Credential
import dev.anuz.quickinbox.domain.User
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

sealed class SessionPhase {
    data object Booting : SessionPhase()
    data class Onboarding(val message: String? = null) : SessionPhase()
    data class Authenticated(val user: User) : SessionPhase()
    data class RestoreFailed(val message: String) : SessionPhase()
}

class AppSession(
    val api: QuickInboxApi,
    val credentialStore: CredentialStore,
    val mailboxCache: MailboxCache,
    val preferences: AppPreferences
) {
    private val mutex = Mutex()
    private val _phase = MutableStateFlow<SessionPhase>(SessionPhase.Booting)
    val phase: StateFlow<SessionPhase> = _phase.asStateFlow()

    private var hasBootstrapped = false
    private var restoreGeneration = 0

    init {
        api.onUnauthorized = {
            // Network threads may observe 401 while a mailbox is open.
            // The UI collects phase and returns to onboarding.
        }
    }

    suspend fun bootstrapIfNeeded() {
        mutex.withLock {
            if (hasBootstrapped) return
            hasBootstrapped = true
        }
        restoreSession()
    }

    suspend fun retryRestore() = restoreSession()

    fun didAuthenticate(credential: Credential, user: User) {
        restoreGeneration += 1
        preferences.cachedUser = user
        api.install(credential)
        _phase.value = SessionPhase.Authenticated(user)
    }

    fun didDisconnect(message: String?) {
        restoreGeneration += 1
        preferences.cachedUser = null
        mailboxCache.clearAll()
        api.clearCredential()
        _phase.value = SessionPhase.Onboarding(message)
    }

    suspend fun removeLocalData() {
        restoreGeneration += 1
        preferences.clear()
        withContext(Dispatchers.IO) { credentialStore.delete() }
        api.clearCredential()
        mailboxCache.clearAll()
        _phase.value = SessionPhase.Onboarding(null)
    }

    fun handleUnauthorized() {
        restoreGeneration += 1
        preferences.cachedUser = null
        try {
            credentialStore.delete()
        } catch (_: Exception) {
        }
        api.clearCredential()
        mailboxCache.clearAll()
        _phase.value = SessionPhase.Onboarding("Your saved session is no longer valid. Connect this device again.")
    }

    private suspend fun restoreSession() {
        restoreGeneration += 1
        val generation = restoreGeneration
        _phase.value = SessionPhase.Booting

        try {
            val credential = withContext(Dispatchers.IO) { credentialStore.load() }
            if (credential == null) {
                api.clearCredential()
                if (generation == restoreGeneration) _phase.value = SessionPhase.Onboarding(null)
                return
            }
            if (credential.isExpired) {
                preferences.cachedUser = null
                withContext(Dispatchers.IO) { credentialStore.delete() }
                api.clearCredential()
                if (generation == restoreGeneration) {
                    _phase.value = SessionPhase.Onboarding(
                        "Your saved session expired. Connect this device again."
                    )
                }
                return
            }

            api.install(credential)
            val cachedUser = credential.cachedUser ?: preferences.cachedUser
            if (cachedUser != null && generation == restoreGeneration) {
                _phase.value = SessionPhase.Authenticated(cachedUser)
            }

            val user = withContext(Dispatchers.IO) { api.currentUser() }
            preferences.cachedUser = user
            if (credential.cachedUser != user) {
                withContext(Dispatchers.IO) { credentialStore.save(credential.caching(user)) }
            }
            if (generation == restoreGeneration) _phase.value = SessionPhase.Authenticated(user)
        } catch (_: ApiError.Unauthorized) {
            preferences.cachedUser = null
            withContext(Dispatchers.IO) { runCatching { credentialStore.delete() } }
            api.clearCredential()
            if (generation == restoreGeneration) {
                _phase.value = SessionPhase.Onboarding(
                    "Your saved session is no longer valid. Connect this device again."
                )
            }
        } catch (_: ApiError.CorruptCredential) {
            preferences.cachedUser = null
            api.clearCredential()
            if (generation == restoreGeneration) {
                _phase.value = SessionPhase.Onboarding(
                    "The saved session was invalid and has been removed."
                )
            }
        } catch (error: ApiError.Transport) {
            if (generation != restoreGeneration) return
            val saved = withContext(Dispatchers.IO) { runCatching { credentialStore.load() }.getOrNull() }
            val cachedUser = saved?.cachedUser ?: preferences.cachedUser
            if (cachedUser != null) {
                if (_phase.value is SessionPhase.Booting) {
                    _phase.value = SessionPhase.Authenticated(cachedUser)
                }
            } else if (_phase.value is SessionPhase.Booting) {
                _phase.value = SessionPhase.RestoreFailed(
                    "QuickInbox couldn’t reach your server and this account has not been cached yet."
                )
            }
        } catch (error: Exception) {
            if (generation != restoreGeneration) return
            if (_phase.value is SessionPhase.Booting) {
                _phase.value = SessionPhase.RestoreFailed(
                    error.message?.takeIf { it.isNotBlank() }
                        ?: "QuickInbox couldn’t reach your server. Check your connection and try again."
                )
            }
        }
    }
}
