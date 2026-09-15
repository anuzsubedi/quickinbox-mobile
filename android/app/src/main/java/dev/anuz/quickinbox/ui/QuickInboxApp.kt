package dev.anuz.quickinbox.ui

import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.anuz.quickinbox.data.AppContainer
import dev.anuz.quickinbox.data.SessionPhase
import dev.anuz.quickinbox.domain.Pairing
import dev.anuz.quickinbox.domain.pairingHost
import dev.anuz.quickinbox.domain.validatePairing
import dev.anuz.quickinbox.domain.validatePayload
import dev.anuz.quickinbox.ui.onboarding.OnboardingScreen
import dev.anuz.quickinbox.ui.pairing.ConfirmPairingSheet
import dev.anuz.quickinbox.ui.pairing.ManualPairingSheet
import dev.anuz.quickinbox.ui.privacy.PrivacyScreen
import dev.anuz.quickinbox.ui.scanner.ScannerScreen
import dev.anuz.quickinbox.ui.session.RestoreFailedScreen
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext


@Composable
fun QuickInboxApp() {
    val container = LocalAppContainer.current
    val session = container.session
    val phase by session.phase.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { session.bootstrapIfNeeded() }

    when (val current = phase) {
        SessionPhase.Booting -> LaunchScreen()
        is SessionPhase.Onboarding -> OnboardingFlow(
            initialMessage = current.message,
            onAuthenticated = session::didAuthenticate
        )
        is SessionPhase.Authenticated -> AuthenticatedRoot(
            container = container,
            user = current.user,
            onDisconnected = { message ->
                session.didDisconnect(message)
            }
        )
        is SessionPhase.RestoreFailed -> RestoreFailedScreen(
            message = current.message,
            onRetry = { scope.launch { session.retryRestore() } },
            onRemoveLocalData = { scope.launch { session.removeLocalData() } }
        )
    }
}

@Composable
private fun OnboardingFlow(
    initialMessage: String?,
    onAuthenticated: (dev.anuz.quickinbox.domain.Credential, dev.anuz.quickinbox.domain.User) -> Unit
) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    val navController = rememberNavController()
    var showManual by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf(initialMessage) }
    var scanned by remember { mutableStateOf<Pairing?>(null) }
    var server by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var connecting by remember { mutableStateOf(false) }

    LaunchedEffect(initialMessage) { if (error == null) error = initialMessage }

    fun connect(pairing: Pairing) {
        if (connecting) return
        connecting = true
        error = null
        scope.launch {
            var installed = false
            try {
                val restorable = withContext(Dispatchers.IO) {
                    val credential = container.api.pair(
                        origin = pairing.origin,
                        code = pairing.code,
                        deviceName = "QuickInbox for Android"
                    )
                    container.api.install(credential)
                    installed = true
                    val user = container.api.currentUser()
                    val saved = credential.caching(user)
                    container.api.install(saved)
                    container.credentialStore.save(saved)
                    saved to user
                }
                connecting = false
                scanned = null
                showManual = false
                onAuthenticated(restorable.first, restorable.second)
            } catch (e: CancellationException) {
                if (installed) cleanupInstalledPairing(container)
                throw e
            } catch (e: Exception) {
                if (installed) {
                    cleanupInstalledPairing(container)
                }
                error = e.message ?: "Couldn’t connect to this server."
                scanned = null
            } finally {
                connecting = false
            }
        }
    }

    QuickInboxNavHost(navController, startDestination = "home") {
        composable("home") { OnboardingScreen(
            error = error,
            onScan = { error = null; navController.navigate("scanner") { launchSingleTop = true } },
            onManual = { error = null; showManual = true },
            onPrivacy = { navController.navigate("privacy") { launchSingleTop = true } }
        )
        }
        composable("scanner") { ScannerScreen(
            onBack = { navController.popBackStack("home", false) },
            onManual = { navController.popBackStack("home", false); showManual = true },
            onScanned = { value ->
                val result = validatePayload(value)
                if (result == null) error = "Invalid pairing code"
                else {
                    scanned = result
                    error = null
                    navController.popBackStack("home", false)
                }
            }
        )
        }
        composable("privacy") { PrivacyScreen(onBack = { navController.popBackStack() }) }
    }

    if (showManual) {
        ManualPairingSheet(
            server = server,
            code = code,
            error = error,
            connecting = connecting,
            onServerChange = { server = it; error = null },
            onCodeChange = { code = it; error = null },
            onDismiss = { if (!connecting) showManual = false },
            onConnect = {
                val result = validatePairing(server, code)
                if (result == null) error = "Check the server and pairing code"
                else connect(result)
            }
        )
    }

    scanned?.let { pairing ->
        ConfirmPairingSheet(
            host = pairingHost(pairing.origin),
            connecting = connecting,
            onDismiss = { if (!connecting) scanned = null },
            onConnect = { connect(pairing) }
        )
    }
}

private suspend fun cleanupInstalledPairing(container: AppContainer) {
    withContext(NonCancellable + Dispatchers.IO) {
        try {
            container.api.logout(container.credentialStore)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
        } finally {
            container.api.clearCredential()
        }
    }
}
