package dev.anuz.quickinbox.ui

import androidx.compose.runtime.staticCompositionLocalOf
import dev.anuz.quickinbox.data.AppContainer

val LocalAppContainer = staticCompositionLocalOf<AppContainer> {
    error("AppContainer is not provided")
}
