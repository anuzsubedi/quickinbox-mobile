package dev.anuz.quickinbox.data

import android.content.Context
import com.google.gson.Gson
import dev.anuz.quickinbox.domain.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class MailboxNavigationStyle {
    Native,
    Legacy
}

class AppPreferences(context: Context, private val gson: Gson) {
    private val prefs = context.getSharedPreferences("quickinbox_prefs", Context.MODE_PRIVATE)
    private val _themeId = MutableStateFlow(prefs.getString(APP_THEME, DEFAULT_THEME) ?: DEFAULT_THEME)
    val themeId = _themeId.asStateFlow()
    private val _mailboxNavigationStyle = MutableStateFlow(
        prefs.getString(MAILBOX_NAVIGATION_STYLE, null)
            ?.let { stored -> MailboxNavigationStyle.entries.firstOrNull { it.name == stored } }
            ?: MailboxNavigationStyle.Legacy
    )
    val mailboxNavigationStyle = _mailboxNavigationStyle.asStateFlow()
    private val existingAccountAtStartup = prefs.contains(CACHED_USER)
    private val _navigationPromptPending = MutableStateFlow(
        !prefs.getBoolean(NAVIGATION_PROMPT_COMPLETED, false) && !existingAccountAtStartup
    )
    val navigationPromptPending = _navigationPromptPending.asStateFlow()

    init {
        // Do not present new onboarding retroactively to users upgrading an existing account.
        if (existingAccountAtStartup && !prefs.contains(NAVIGATION_PROMPT_COMPLETED)) {
            prefs.edit().putBoolean(NAVIGATION_PROMPT_COMPLETED, true).apply()
        }
    }

    var selectedThemeId: String
        get() = _themeId.value
        set(value) {
            prefs.edit().putString(APP_THEME, value).apply()
            _themeId.value = value
        }

    var selectedMailboxNavigationStyle: MailboxNavigationStyle
        get() = _mailboxNavigationStyle.value
        set(value) {
            prefs.edit().putString(MAILBOX_NAVIGATION_STYLE, value.name).apply()
            _mailboxNavigationStyle.value = value
        }

    fun completeNavigationPrompt(style: MailboxNavigationStyle) {
        prefs.edit()
            .putString(MAILBOX_NAVIGATION_STYLE, style.name)
            .putBoolean(NAVIGATION_PROMPT_COMPLETED, true)
            .apply()
        _mailboxNavigationStyle.value = style
        _navigationPromptPending.value = false
    }

    var cachedUser: User?
        get() = prefs.getString(CACHED_USER, null)?.let {
            try {
                gson.fromJson(it, User::class.java)
            } catch (_: Exception) {
                null
            }
        }
        set(value) {
            prefs.edit().apply {
                if (value == null) remove(CACHED_USER) else putString(CACHED_USER, gson.toJson(value))
            }.apply()
        }

    var selectedSendingAddressId: String?
        get() = prefs.getString(SENDING_ADDRESS, null)
        set(value) {
            prefs.edit().apply {
                if (value == null) remove(SENDING_ADDRESS) else putString(SENDING_ADDRESS, value)
            }.apply()
        }

    var showRemoteImagesByDefault: Boolean
        get() = prefs.getBoolean(REMOTE_IMAGES, false)
        set(value) {
            prefs.edit().putBoolean(REMOTE_IMAGES, value).apply()
        }

    fun clear() {
        prefs.edit().clear().apply()
        _themeId.value = DEFAULT_THEME
        _mailboxNavigationStyle.value = MailboxNavigationStyle.Legacy
        _navigationPromptPending.value = true
    }

    companion object {
        private const val CACHED_USER = "quickinbox.cachedUser"
        private const val SENDING_ADDRESS = "quickinbox.selectedSendingAddressID"
        private const val REMOTE_IMAGES = "quickinbox.privacy.showRemoteImagesByDefault"
        private const val APP_THEME = "quickinbox.appearance.theme"
        private const val MAILBOX_NAVIGATION_STYLE = "quickinbox.appearance.mailboxNavigationStyle"
        private const val NAVIGATION_PROMPT_COMPLETED = "quickinbox.onboarding.navigationPromptCompleted"
        private const val DEFAULT_THEME = "monet"
    }
}
