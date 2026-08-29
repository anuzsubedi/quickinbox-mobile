package dev.anuz.quickinbox.ui.onboarding

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.QrCodeScanner
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import dev.anuz.quickinbox.R
import dev.anuz.quickinbox.ui.theme.BricolageGrotesque

@Composable
fun OnboardingScreen(
    error: String?,
    onScan: () -> Unit,
    onManual: () -> Unit,
    onPrivacy: () -> Unit
) {
    Scaffold(containerColor = MaterialTheme.colorScheme.background) { contentPadding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(contentPadding).padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(8.dp))
            AppBrand()
            Column(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Image(
                    painter = painterResource(R.drawable.onboarding_inbox_mark),
                    contentDescription = null,
                    modifier = Modifier.fillMaxWidth().aspectRatio(3f / 2f),
                    contentScale = ContentScale.Fit
                )
                Spacer(Modifier.height(22.dp))
                Text(
                    "Connect to your\nprivate server",
                    fontFamily = BricolageGrotesque,
                    fontWeight = FontWeight(560),
                    fontSize = 34.sp,
                    lineHeight = (34 * 1.04).sp,
                    letterSpacing = (-0.035).em,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(10.dp))
                Text(
                    "Connect securely to continue",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
            error?.let {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.errorContainer
                ) {
                    Text(
                        it,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        color = MaterialTheme.colorScheme.onErrorContainer
                    )
                }
                Spacer(Modifier.height(12.dp))
            }
            Button(
                onClick = onScan,
                modifier = Modifier.fillMaxWidth().height(56.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                Icon(Icons.Rounded.QrCodeScanner, contentDescription = null)
                Spacer(Modifier.width(10.dp))
                Text("Scan QR code", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(10.dp))
            FilledTonalButton(
                onClick = onManual,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                Icon(Icons.Rounded.Keyboard, contentDescription = null)
                Spacer(Modifier.width(10.dp))
                Text("Enter code")
            }
            Spacer(Modifier.height(16.dp))
            PrivacyAgreement(onPrivacy)
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun AppBrand() {
    Row(
        modifier = Modifier.fillMaxWidth().height(32.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Image(
            painter = painterResource(R.drawable.ic_quickinbox),
            contentDescription = null,
            modifier = Modifier.size(32.dp)
        )
        Spacer(Modifier.width(6.dp))
        Text(
            "QuickInbox",
            style = TextStyle(
                fontFamily = BricolageGrotesque,
                fontWeight = FontWeight(620),
                fontSize = 16.sp,
                letterSpacing = (-0.03).em,
                lineHeight = 16.sp,
                platformStyle = PlatformTextStyle(includeFontPadding = false),
                lineHeightStyle = LineHeightStyle(
                    alignment = LineHeightStyle.Alignment.Center,
                    trim = LineHeightStyle.Trim.Both
                )
            )
        )
    }
}

@Composable
private fun PrivacyAgreement(onPrivacy: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val text = buildAnnotatedString {
        append("By continuing you agree to the ")
        withLink(
            LinkAnnotation.Clickable(
                tag = "privacy",
                styles = TextLinkStyles(
                    style = SpanStyle(color = colors.primary, fontWeight = FontWeight.Medium)
                ),
                linkInteractionListener = { onPrivacy() }
            )
        ) {
            append("privacy policy")
        }
    }
    Text(
        text = text,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
        color = colors.onSurfaceVariant,
        style = MaterialTheme.typography.bodySmall,
        textAlign = TextAlign.Center
    )
}
