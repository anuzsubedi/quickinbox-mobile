package dev.anuz.quickinbox.ui

import android.net.Uri
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import dev.anuz.quickinbox.domain.Pairing
import dev.anuz.quickinbox.domain.validatePairing
import dev.anuz.quickinbox.domain.validatePayload
import dev.anuz.quickinbox.ui.onboarding.OnboardingScreen
import dev.anuz.quickinbox.ui.pairing.ManualPairingSheet
import dev.anuz.quickinbox.ui.privacy.PrivacyScreen
import dev.anuz.quickinbox.ui.scanner.ScannerScreen

private enum class Screen { Onboarding, Scanner, Privacy }

@Composable
fun QuickInboxApp() {
    var screen by remember { mutableStateOf(Screen.Onboarding) }
    var showManual by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var scanned by remember { mutableStateOf<Pairing?>(null) }
    var server by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }

    when (screen) {
        Screen.Onboarding -> OnboardingScreen(
            error = error,
            onScan = { error = null; screen = Screen.Scanner },
            onManual = { error = null; showManual = true },
            onPrivacy = { screen = Screen.Privacy }
        )
        Screen.Scanner -> ScannerScreen(
            onBack = { screen = Screen.Onboarding },
            onManual = { screen = Screen.Onboarding; showManual = true },
            onScanned = { value ->
                val result = validatePayload(value)
                if (result == null) error = "Invalid pairing code"
                else {
                    scanned = result
                    error = null
                    screen = Screen.Onboarding
                }
            }
        )
        Screen.Privacy -> PrivacyScreen(onBack = { screen = Screen.Onboarding })
    }

    if (showManual) {
        ManualPairingSheet(
            server = server,
            code = code,
            error = error,
            onServerChange = { server = it; error = null },
            onCodeChange = { code = it; error = null },
            onDismiss = { showManual = false },
            onConnect = {
                val result = validatePairing(server, code)
                if (result == null) error = "Check the server and pairing code"
                else {
                    scanned = result
                    error = null
                    showManual = false
                }
            }
        )
    }

    scanned?.let { pairing ->
        AlertDialog(
            onDismissRequest = { scanned = null },
            icon = { Icon(Icons.Rounded.Lock, contentDescription = null) },
            title = { Text("Confirm server") },
            text = { Text(Uri.parse(pairing.origin).host ?: pairing.origin) },
            confirmButton = { Button(onClick = { scanned = null }) { Text("Connect") } },
            dismissButton = { TextButton(onClick = { scanned = null }) { Text("Cancel") } }
        )
    }
}
