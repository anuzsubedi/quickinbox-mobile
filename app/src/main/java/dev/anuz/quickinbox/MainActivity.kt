package dev.anuz.quickinbox

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.anuz.quickinbox.ui.QuickInboxApp
import dev.anuz.quickinbox.ui.theme.QuickInboxTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { QuickInboxTheme { QuickInboxApp() } }
    }
}
