package dev.anuz.quickinbox

import android.os.Bundle
import android.graphics.Color as AndroidColor
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import dev.anuz.quickinbox.ui.LocalAppContainer
import dev.anuz.quickinbox.ui.QuickInboxApp
import dev.anuz.quickinbox.ui.theme.AppThemeOption
import dev.anuz.quickinbox.ui.theme.QuickInboxTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val container = (application as QuickInboxApplication).container
        setContent {
            val themeId by container.preferences.themeId.collectAsState()
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
            }
            CompositionLocalProvider(LocalAppContainer provides container) {
                QuickInboxTheme(themeId = themeId) { QuickInboxApp() }
            }
        }
    }
}
