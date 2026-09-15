package dev.anuz.quickinbox.ui

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import dev.anuz.quickinbox.ui.theme.QuickInboxMotion

/** Shared Back motion for every screen stack, also seekable by predictive Back. */
@Composable
fun QuickInboxNavHost(
    navController: NavHostController,
    startDestination: String,
    modifier: Modifier = Modifier,
    builder: NavGraphBuilder.() -> Unit
) {
    val travel = with(LocalDensity.current) { 30.dp.roundToPx() }
    NavHost(
        navController = navController,
        startDestination = startDestination,
        modifier = modifier,
        popEnterTransition = {
            slideInVertically(
                tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard),
                initialOffsetY = { -travel }
            ) + fadeIn(tween(QuickInboxMotion.DurationMedium))
        },
        popExitTransition = {
            slideOutVertically(
                tween(QuickInboxMotion.DurationMedium, easing = QuickInboxMotion.Standard),
                targetOffsetY = { travel }
            ) + fadeOut(tween(QuickInboxMotion.DurationShort))
        },
        builder = builder
    )
}
