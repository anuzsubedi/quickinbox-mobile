package dev.anuz.quickinbox.ui

import dev.anuz.quickinbox.ui.compose.ComposeMode
import org.junit.Assert.assertEquals
import org.junit.Test

class NavigationArgumentsTest {
    @Test
    fun composeModesSurviveSavedRouteRestoration() {
        val gson = navigationGson()
        val modes = listOf(
            ComposeMode.NewMessage,
            ComposeMode.Draft("draft/with?reserved#characters"),
            ComposeMode.Reply("message-1", "test@example.com", "Re: Hello / 世界", replyAll = true),
            ComposeMode.Forward.Message("message-1", "Fwd: hello", attachmentCount = 2),
            ComposeMode.Forward.Thread("thread-1", "Fwd: thread", messageCount = 3, attachmentCount = 4)
        )
        modes.forEachIndexed { index, mode ->
            val original = AuthDestination.Compose(mode, sessionKey = index)
            val restored = gson.fromJson(gson.toJson(original), AuthDestination.Compose::class.java)
            assertEquals(original, restored)
        }
    }
}
