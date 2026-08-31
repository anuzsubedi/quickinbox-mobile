package dev.anuz.quickinbox.ui.compose

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.anuz.quickinbox.ui.components.SenderTile

private val ChipShape = RoundedCornerShape(8.dp)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RecipientChipField(
    label: String,
    recipients: List<String>,
    onRecipientsChange: (List<String>) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    recipientNames: Map<String, String> = emptyMap(),
    leadingIcon: @Composable (() -> Unit)? = null,
    trailing: @Composable (() -> Unit)? = null
) {
    var draft by remember { mutableStateOf("") }
    var hadFocus by remember { mutableStateOf(false) }

    fun commitDraft() {
        val candidate = draft.trim().trimEnd(',', ';')
        if (candidate.isEmpty()) {
            draft = ""
            return
        }
        if (candidate !in recipients) {
            onRecipientsChange(recipients + candidate)
        }
        draft = ""
    }

    fun removeAt(index: Int) {
        if (!enabled) return
        onRecipientsChange(recipients.filterIndexed { i, _ -> i != index })
    }

    Column(modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .padding(start = 20.dp, end = 8.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (leadingIcon != null) {
                Row(
                    modifier = Modifier.widthIn(min = 40.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    leadingIcon()
                }
            } else {
                Text(
                    label,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.widthIn(min = 40.dp)
                )
            }
            FlowRow(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                    recipients.forEachIndexed { index, address ->
                        RecipientChip(
                            address = address,
                            displayName = recipientNames[address],
                            enabled = enabled,
                            onRemove = { removeAt(index) }
                        )
                    }
                    BasicTextField(
                        value = draft,
                        onValueChange = { newValue ->
                            if (!enabled) return@BasicTextField
                            when {
                                newValue.endsWith(',') || newValue.endsWith(';') -> {
                                    draft = newValue.dropLast(1)
                                    commitDraft()
                                }
                                newValue.contains(' ') && newValue.trim().isNotEmpty() -> {
                                    draft = newValue.trim()
                                    commitDraft()
                                }
                                else -> draft = newValue
                            }
                        },
                        modifier = Modifier
                            .widthIn(min = 48.dp, max = 220.dp)
                            .onFocusChanged { focus ->
                                if (hadFocus && !focus.isFocused) commitDraft()
                                hadFocus = focus.isFocused
                            },
                        enabled = enabled,
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodyLarge.copy(
                            color = MaterialTheme.colorScheme.onSurface
                        ),
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Next
                        ),
                        keyboardActions = KeyboardActions(onNext = { commitDraft() }),
                        decorationBox = { innerField ->
                            if (draft.isEmpty() && recipients.isEmpty() && leadingIcon != null) {
                                Text(
                                    label,
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            innerField()
                        }
                    )
            }
            if (trailing != null) {
                trailing()
            }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }

    LaunchedEffect(enabled) {
        if (!enabled) commitDraft()
    }
}

@Composable
private fun RecipientChip(
    address: String,
    displayName: String?,
    enabled: Boolean,
    onRemove: () -> Unit
) {
    Surface(
        shape = if (displayName == null) ChipShape else RoundedCornerShape(18.dp),
        color = if (displayName == null) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
        border = if (displayName == null) null else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        tonalElevation = 0.dp
    ) {
        Row(
            modifier = Modifier.padding(
                start = if (displayName == null) 10.dp else 3.dp,
                end = 2.dp,
                top = 3.dp,
                bottom = 3.dp
            ),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (displayName != null) {
                SenderTile(
                    name = displayName,
                    size = 28.dp,
                    shape = CircleShape
                )
                Spacer(Modifier.widthIn(min = 6.dp))
            }
            Text(
                displayName ?: address,
                style = MaterialTheme.typography.bodyMedium,
                color = if (displayName == null) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.widthIn(max = 180.dp)
            )
            if (displayName == null) {
                IconButton(
                    onClick = onRemove,
                    enabled = enabled,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Rounded.Close,
                        contentDescription = "Remove $address",
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}
