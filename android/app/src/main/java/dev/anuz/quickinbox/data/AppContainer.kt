package dev.anuz.quickinbox.data

import android.content.Context
import com.google.gson.GsonBuilder
import java.util.Date

class AppContainer(context: Context) {
    val gson = GsonBuilder()
        .registerTypeAdapter(Date::class.java, ApiDateAdapter())
        .create()

    private val networkStatus = NetworkStatus(context)
    val api = QuickInboxApi(gson, hasInternetAccess = networkStatus::hasInternetAccess)
    val credentialStore = CredentialStore(context, gson)
    val mailboxCache = MailboxCache(context, gson)
    val threadCache = ThreadCache(context, gson)
    val preferences = AppPreferences(context, gson)
    val appLock = AppLockController(context)
    val session = AppSession(api, credentialStore, mailboxCache, threadCache, preferences)

    init {
        api.onUnauthorized = { session.handleUnauthorized() }
    }
}
