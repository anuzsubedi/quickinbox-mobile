package dev.anuz.quickinbox.data

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.IOException
import java.net.UnknownHostException

class NetworkErrorMapperTest {
    @Test
    fun offlineConnectionUsesActionableOfflineMessage() {
        val error = IOException("raw socket failure").toTransportError(
            host = "mail.example",
            hasInternetAccess = { false }
        )

        assertEquals(
            "No internet connection. Connect to Wi-Fi or mobile data and try again.",
            error.message
        )
    }

    @Test
    fun unknownHostWhileOnlineIdentifiesDnsOrAddressProblem() {
        val error = UnknownHostException("raw resolver failure").toTransportError(
            host = "mail.example",
            hasInternetAccess = { true }
        )

        assertEquals(
            "QuickInbox couldn’t find mail.example. Check the server address or DNS settings.",
            error.message
        )
    }

    @Test
    fun otherOnlineTransportFailuresIdentifyUnavailableServer() {
        val error = IOException("connection refused").toTransportError(
            host = "mail.example",
            hasInternetAccess = { true }
        )

        assertEquals(
            "QuickInbox can’t reach mail.example. The server may be unavailable. Try again later.",
            error.message
        )
    }
}
