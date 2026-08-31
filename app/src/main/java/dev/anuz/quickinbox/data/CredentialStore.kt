package dev.anuz.quickinbox.data

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import dev.anuz.quickinbox.domain.Credential

class CredentialStore(context: Context, private val gson: Gson) {
    private val prefs = EncryptedSharedPreferences.create(
        context,
        PREFS_NAME,
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun load(): Credential? {
        val json = prefs.getString(KEY, null) ?: return null
        return try {
            gson.fromJson(json, Credential::class.java)
        } catch (_: JsonSyntaxException) {
            delete()
            throw ApiError.CorruptCredential()
        }
    }

    fun save(credential: Credential) {
        prefs.edit().putString(KEY, gson.toJson(credential)).apply()
    }

    fun delete() {
        prefs.edit().remove(KEY).apply()
    }

    companion object {
        const val PREFS_NAME = "quickinbox_credentials"
        private const val KEY = "mobile-session"
    }
}
