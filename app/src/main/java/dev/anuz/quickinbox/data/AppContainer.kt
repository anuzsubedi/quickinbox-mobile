package dev.anuz.quickinbox.data

import android.content.Context
import com.google.gson.GsonBuilder
import java.util.Date

class AppContainer(context: Context) {
    val gson = GsonBuilder()
        .registerTypeAdapter(Date::class.java, ApiDateAdapter())
        .create()

    val api = QuickInboxApi(gson)
    val credentialStore = CredentialStore(context, gson)
    val mailboxCache = MailboxCache(context, gson)
    val preferences = AppPreferences(context, gson)
    val session = AppSession(api, credentialStore, mailboxCache, preferences)

    init {
        api.onUnauthorized = { session.handleUnauthorized() }
    }
}
