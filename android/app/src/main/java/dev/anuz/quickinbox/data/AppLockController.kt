package dev.anuz.quickinbox.data

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.edit
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

data class AppLockState(
    val isEnabled: Boolean,
    val isLocked: Boolean,
    val isAvailable: Boolean,
    val isAuthenticating: Boolean = false,
    val errorMessage: String? = null
)

/**
 * Owns the local App Lock preference and all transitions into and out of the locked state.
 * Device credentials are accepted as a fallback so users cannot be stranded by a temporarily
 * unavailable or locked-out biometric sensor.
 */
class AppLockController(context: Context) {
    private val applicationContext = context.applicationContext
    private val preferences = applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    private val biometricManager = BiometricManager.from(applicationContext)
    private val _state = MutableStateFlow(initialState())
    val state = _state.asStateFlow()

    private enum class AuthenticationPurpose { Enable, Disable, Unlock }

    fun refreshAvailability() {
        val available = canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
        _state.value = _state.value.copy(
            isAvailable = available,
            isLocked = _state.value.isLocked || (_state.value.isEnabled && !available)
        )
    }

    fun requestSetEnabled(activity: FragmentActivity, enabled: Boolean) {
        if (!enabled) {
            refreshAvailability()
            if (!_state.value.isAvailable) {
                _state.value = _state.value.copy(errorMessage = availabilityMessage())
                return
            }
            authenticate(activity, AuthenticationPurpose.Disable)
            return
        }

        refreshAvailability()
        if (!_state.value.isAvailable) {
            _state.value = _state.value.copy(errorMessage = availabilityMessage())
            return
        }
        authenticate(activity, AuthenticationPurpose.Enable)
    }

    fun requestUnlock(activity: FragmentActivity) {
        val current = _state.value
        if (!current.isEnabled || !current.isLocked || current.isAuthenticating) return
        refreshAvailability()
        if (!_state.value.isAvailable) {
            _state.value = _state.value.copy(errorMessage = availabilityMessage())
            return
        }
        authenticate(activity, AuthenticationPurpose.Unlock)
    }

    fun lock() {
        val current = _state.value
        if (current.isEnabled) {
            _state.value = current.copy(isLocked = true, errorMessage = null)
        }
    }

    private fun authenticate(activity: FragmentActivity, purpose: AuthenticationPurpose) {
        if (_state.value.isAuthenticating) return
        _state.value = _state.value.copy(isAuthenticating = true, errorMessage = null)

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    when (purpose) {
                        AuthenticationPurpose.Enable -> {
                            preferences.edit { putBoolean(ENABLED, true) }
                            _state.value = _state.value.copy(
                                isEnabled = true,
                                isLocked = false,
                                isAuthenticating = false,
                                errorMessage = null
                            )
                        }
                        AuthenticationPurpose.Disable -> {
                            preferences.edit { remove(ENABLED) }
                            _state.value = _state.value.copy(
                                isEnabled = false,
                                isLocked = false,
                                isAuthenticating = false,
                                errorMessage = null
                            )
                        }
                        AuthenticationPurpose.Unlock -> {
                            _state.value = _state.value.copy(
                                isLocked = false,
                                isAuthenticating = false,
                                errorMessage = null
                            )
                        }
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    val message = when (errorCode) {
                        BiometricPrompt.ERROR_CANCELED,
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                        BiometricPrompt.ERROR_USER_CANCELED -> null
                        BiometricPrompt.ERROR_LOCKOUT,
                        BiometricPrompt.ERROR_LOCKOUT_PERMANENT ->
                            "Biometrics are temporarily locked. Use your screen lock to try again."
                        BiometricPrompt.ERROR_HW_UNAVAILABLE ->
                            "Device authentication is temporarily unavailable. Try again."
                        BiometricPrompt.ERROR_NO_BIOMETRICS,
                        BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> availabilityMessage()
                        else -> "QuickInbox couldn't verify your identity. Try again."
                    }
                    _state.value = _state.value.copy(
                        isAuthenticating = false,
                        errorMessage = message
                    )
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    _state.value = _state.value.copy(
                        errorMessage = "That biometric wasn't recognized. Try again."
                    )
                }
            }
        )

        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle(
                    when (purpose) {
                        AuthenticationPurpose.Enable -> "Enable QuickInbox App Lock"
                        AuthenticationPurpose.Disable -> "Disable QuickInbox App Lock"
                        AuthenticationPurpose.Unlock -> "Unlock QuickInbox"
                    }
                )
                .setSubtitle(
                    when (purpose) {
                        AuthenticationPurpose.Enable -> "Confirm your identity to protect your mail"
                        AuthenticationPurpose.Disable -> "Confirm your identity to remove protection"
                        AuthenticationPurpose.Unlock -> "Authenticate to view your mail"
                    }
                )
                .setAllowedAuthenticators(AUTHENTICATORS)
                .build()
        )
    }

    private fun initialState(): AppLockState {
        val enabled = preferences.getBoolean(ENABLED, false)
        val available = canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
        return AppLockState(
            isEnabled = enabled,
            isLocked = enabled,
            isAvailable = available
        )
    }

    private fun canAuthenticate(): Int = biometricManager.canAuthenticate(AUTHENTICATORS)

    private fun availabilityMessage(): String = when (canAuthenticate()) {
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
            "Set up biometrics or a screen lock in Android Settings before enabling App Lock."
        BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
            "Device authentication is temporarily unavailable. Try again."
        else -> "This device can't use biometrics or a screen lock for App Lock."
    }

    private companion object {
        const val PREFERENCES = "quickinbox_app_lock"
        const val ENABLED = "quickinbox.biometricLockEnabled"
        const val AUTHENTICATORS =
            BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
    }
}
