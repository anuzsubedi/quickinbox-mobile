package dev.anuz.quickinbox

import android.app.Application
import dev.anuz.quickinbox.data.AppContainer

class QuickInboxApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
