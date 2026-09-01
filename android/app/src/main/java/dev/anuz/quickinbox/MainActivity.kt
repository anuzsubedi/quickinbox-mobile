package dev.anuz.quickinbox

import android.os.Bundle
import android.graphics.Color as AndroidColor
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import android.view.WindowManager
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.anuz.quickinbox.ui.LocalAppContainer
import dev.anuz.quickinbox.ui.AppLockScreen
import dev.anuz.quickinbox.ui.QuickInboxApp
import dev.anuz.quickinbox.ui.theme.AppThemeOption
import dev.anuz.quickinbox.ui.theme.QuickInboxTheme

class MainActivity : AppCompatActivity() {
    private val appContainer by lazy { (application as QuickInboxApplication).container }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val themeId by appContainer.preferences.themeId.collectAsStateWithLifecycle()
            val appLockState by appContainer.appLock.state.collectAsStateWithLifecycle()
            val option = AppThemeOption.fromId(themeId)
            val dark = option.forcedDark ?: isSystemInDarkTheme()
            SideEffect {
                val transparent = AndroidColor.TRANSPARENT
                val systemBarStyle = if (dark) {
                    SystemBarStyle.dark(transparent)
                } else {
                    SystemBarStyle.light(transparent, transparent)
                }
                enableEdgeToEdge(systemBarStyle, systemBarStyle)
                if (appLockState.isEnabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
            }
            CompositionLocalProvider(LocalAppContainer provides appContainer) {
                QuickInboxTheme(themeId = themeId) {
                    Box(Modifier.fillMaxSize()) {
                        Box(
                            Modifier
                                .fillMaxSize()
                                .then(
                                    if (appLockState.isLocked) Modifier.clearAndSetSemantics { }
                                    else Modifier
                                )
                        ) {
                            QuickInboxApp()
                        }
                        if (appLockState.isLocked) {
                            AppLockScreen(
                                state = appLockState,
                                onUnlock = { appContainer.appLock.requestUnlock(this@MainActivity) }
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        appContainer.appLock.refreshAvailability()
        appContainer.appLock.requestUnlock(this)
    }

    override fun onStop() {
        if (!isChangingConfigurations) appContainer.appLock.lock()
        super.onStop()
    }

    override fun onUserLeaveHint() {
        appContainer.appLock.lock()
        super.onUserLeaveHint()
    }
}
