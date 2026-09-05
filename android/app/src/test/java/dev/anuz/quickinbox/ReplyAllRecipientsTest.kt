package dev.anuz.quickinbox

import dev.anuz.quickinbox.ui.compose.ComposeMode
import dev.anuz.quickinbox.ui.compose.replyAllCc
import org.junit.Assert.assertEquals
import org.junit.Test

class ReplyAllRecipientsTest {
    @Test fun replyAllExcludesSenderSelfAndDuplicateRecipients() {
        val mode = ComposeMode.Reply(
            messageId = "message", recipient = "Sender <sender@example.com>", subject = "Re: Hello",
            fromAddressHint = "me@example.com",
            originalTo = "me@example.com, Teammate <team@example.com>",
            originalCc = "sender@example.com, TEAM@example.com, alias@example.com, other@example.com",
            replyAll = true
        )
        assertEquals(listOf("team@example.com", "other@example.com"), mode.replyAllCc(listOf("alias@example.com")))
    }

    @Test fun oneToOneReplyAllHasNoExtraRecipients() {
        val mode = ComposeMode.Reply(
            messageId = "message", recipient = "sender@example.com", subject = "Hello",
            fromAddressHint = "me@example.com", originalTo = "me@example.com", replyAll = true
        )
        assertEquals(emptyList<String>(), mode.replyAllCc(emptyList()))
    }
}
