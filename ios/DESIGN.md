# QuickInbox Design System

<!-- impeccable:product-schema 1 -->

<!--
THESIS: Postmark Desk makes a private mailbox feel like intentional correspondence, replacing generic navigation chrome with one compact mail-first hierarchy.
OWN-WORLD: Crisp semantic paper, ink typography, sage postmark seals, a compact type-led masthead, flat mail rows, and restrained native controls.
STORY: The user immediately sees where they are, what needs attention, and can read, triage, or write without navigating through app chrome.
FIRST VIEWPORT: The active mailbox menu, status, search, Compose, and account identity form one compact masthead above a sender-led stream marked by quiet postmark seals.
FORM: Postmark Desk, rebuilt from live iOS 27 simulator evidence rather than inherited large-title, toolbar-glass, or bottom-sheet conventions.
-->

## Direction

QuickInbox is a **Postmark Desk**: a quiet, high-trust place for correspondence
on a server the user controls. A compact type-led masthead establishes location
and identity; mail sits immediately beneath it on a crisp semantic reading
surface. A restrained postmark seal makes sender identity and unread state
recognizable without turning daily mail into a dashboard.

The live simulator is the final test for hierarchy and rhythm. All text,
controls, lists, sheets, materials, and state are native SwiftUI. Unsupported
ideas such as snooze, priority scoring, or global archive commands are not
implied by the interface.

## Navigation

- Mail is the only root destination. There is no tab bar or replacement bottom
  navigation.
- On iPhone, conversations push from a `NavigationStack`; the left-edge back
  gesture remains available.
- Version 1.0 targets iPhone only; do not design or advertise an iPad layout for
  this release.
- The active mailbox name is an anchored native menu in the masthead. It changes
  mailboxes in place; mailbox navigation never opens a bottom sheet.
- Compose is an explicit dock action; account/settings stays in the header. The conversation
  reader has a persistent labeled action bar for replying, forwarding, moving,
  and deleting mail.
- Entering and dismissing Settings must preserve mailbox, search, selection,
  scroll, and draft presentation state.

## Color and material

- **Harbor** is the default adaptive theme. Existing saved theme choices remain
  available and retain their selection. Appearance previews use each theme's own accent.
- Light Harbor uses blue-gray canvas `#F6F9FA`, white raised surfaces, deep ink
  `#192E38`, secondary slate `#526873`, and tidal teal `#17636C`.
- Dark Harbor uses navy canvas `#101E27`, raised slate `#1A2B36`, pale text
  `#E7F0F4`, secondary blue-gray `#A6BBC5`, and teal `#83D2D9`.
- Theme roles cover canvas, grouped surfaces, raised controls, text, separators,
  fills, avatars, accent/on-accent, destructive red, amber stars/warnings, and
  green success. Native system dialogs, camera overlays, and received HTML keep
  their specialized platform/content rendering.
- Primary, secondary, and accent text against all three Harbor surfaces, plus
  on-accent button labels, exceed 4.5:1 in both modes (numeric contrast check).
- Liquid Glass is reserved for floating controls on supported systems, with
  opaque themed fallbacks for older versions and Reduce Transparency.

## Typography

- San Francisco semantic text styles carry the interface and Dynamic Type.
- The mailbox title is the strongest top-level type. It names the current
  mailbox, not the brand or a greeting.
- Rows use sender, subject, preview, then time/state metadata. Unread mail gains
  weight plus a small shape indicator; color is never the only signal.
- Conversation subjects use `title2` semibold; bodies use `body`; addresses,
  timestamps, sizes, and delivery states use `subheadline`, `footnote`, or
  `caption` according to hierarchy.
- Bold is reserved for unread state, page subjects, and primary decisions.
- Fixed point sizes are not used for user-facing type. Machine-readable codes
  may use monospaced styles.

## Mailbox index

- The inbox uses a type-led header with a mailbox menu, summary, and Settings gear.
  On iOS 18+, scrolling collapses the title and summary with separated thresholds
  to avoid flicker. The compact mailbox floats in a glass capsule; the reserved
  expanded inset stays fixed so rows do not jump. Short lists and iOS 17 retain expanded headers. Selection
  starts from a conversation context menu.
- Glass Search and Filter controls sit beside a separate Compose button.
  Search defaults to a compact button and expands when tapped; submitting or
  dismissing focus collapses it again without clearing the query. Bulk Undo temporarily replaces the full capsule.
- Date labels scroll with their rows rather than pinning. The slim scrollbar
  matches main: it follows scroll progress and fades after 750 ms of inactivity.
- Sender-first rows use a native plain iOS list with separators and no cards. They
  use restrained circular initials, a separate unread
  dot, subject, and two-line preview. Dates and state icons stay subordinate.
  Selected rows receive an accent wash and a checkmark in place of initials.
- Selection is an explicit mode, including when no rows are selected. The header
  shows count, Done/clear, and Select All loaded conversations. Bulk actions use
  labeled tiles in a grid that reflows with Dynamic Type.
- Keep all mailbox, filter, swipe, selection, pagination, refresh, and Undo
  behavior intact. Individual Undo placeholders retain the affected row's place.
- Colors follow the active semantic theme; no decorative shadows or simulated
  glass. Respect Dynamic Type, VoiceOver, Reduce Motion, and dark appearance.

## Mailbox menu

- Use an anchored native `Menu`, never a sheet, detent, custom drawer, or bottom
  overlay.
- Each mailbox is an SF Symbol, title, and selected checkmark. Do not invent
  per-mailbox counts that the client has not fetched.
- Settings stays behind the separate account monogram so mailbox switching
  remains a single-purpose task.

## Conversation reader

- The conversation is a document surface. Subject comes first, followed by
  correspondent and message count.
- The newest message starts expanded. In multi-email conversations, messages expand or collapse
  independently; the conversation menu also offers Expand/Collapse All.
- Messages use quiet rounded cards with stable sender and timestamp placement.
  Long-press lifts the whole card using the native context-menu preview and
  system background treatment. Keep HTML rendering unchanged. Collapsed cards
  show a preview; expanded cards show recipient details and the full-width body.
  Disclosure respects Reduce Motion.
- Plain text, formatted HTML, selection, quoted history, links, attachments,
  Quick Look, and share behavior remain accessible.
- Use a title2 subject with quiet conversation metadata and expandable sender
  address details. Star has a direct navigation-bar control. The top-right
  conversation menu contains Reply All, read state, and Expand/Collapse All.
  Keep Star in the navigation bar and Reply, Forward All, move, and trash in
  the bottom controls; do not duplicate them in the overflow menu. Single-email conversations stay open. In longer threads, individual email
  headers offer disclosure without an ellipsis button. Card long-press actions
  are Forward, Copy Sender Address, and Expand/Collapse, also exposed to
  VoiceOver. Per-email forwarding preserves its quoted context. The bottom
  Forward All action forwards the conversation; the top-right menu retains
  conversation actions.
- A labeled bottom action bar exposes Reply, Forward, Archive/Inbox/Restore,
  and Trash/Delete. The bottom bar uses plain labeled controls on a solid
  background with restrained Reply emphasis. Forward uses a single arrow;
  Forward All uses double arrows. Recipient addresses stay inside the expandable
  Recipients & details section, with separate labels and values.
  Actions reflow on narrow layouts and large text sizes; destructive actions
  retain confirmation. Single-email readers omit redundant message-count metadata
  and use a wider reading inset; long threads distinguish quiet collapsed cards
  from expanded reading surfaces.

## Composer

- Compose is a flat mail document: From, To, optional Cc/Bcc, Subject,
  attachments, and one uninterrupted body editor.
- Address rows and labels reflow at accessibility sizes instead of depending on
  fixed label widths.
- Cancel and Send are native navigation actions. Send shows progress in place,
  succeeds with visible and haptic confirmation, and never adds celebration.
- Attachment rows show filename, size, progress, and a 44-point remove action.
- Validation names the missing correction. Discard language reflects whether
  the user is writing a message, reply, or editing a draft.

## Onboarding

- Pairing is scanner-first. The light-only landing screen uses a rounded native
  QuickInbox wordmark, a visible **Privacy** text action, a left-aligned headline,
  and one prominent **Scan QR code** action pinned to the bottom safe-area
  region.
- The original transparent server-to-iPhone illustration sits on a warm blush
  art mat. It is decorative only and contains no scannable QR pattern. The hero
  yields to copy at accessibility text sizes and in compact-height layouts.
- The relationship is described plainly: open QuickInbox on the web, choose
  Settings > Connect mobile app, then scan. The landing also states that the
  connection uses HTTPS and pairing credentials are stored in Keychain.
- Manual entry is available only from inside the scanner, including permission
  denied, unsupported-device, unavailable-camera, and scanner-failure states.
- The scanner uses an edge-to-edge camera surface, custom corner brackets,
  concise guidance, and a solid bottom region for **Enter code manually**.
- Camera permission, scanned-host confirmation, errors, progress, and manual
  entry use system sheets, alerts, fields, and controls. Support and Privacy
  Policy remain available from Settings, with the Privacy Policy also exposed
  before pairing.

## Settings

- Settings opens from the gear into a native inset-grouped list: account,
  Preferences, Account & Access, and Help & About. Destination subtitles explain
  what each page contains, inspired by Android without importing Material UI.
- Subpages use native Forms, section headers/footers, and system disclosure.
  Appearance is a checkmarked theme list; default sender uses a navigation-link
  picker. Signature editing retains its character limit and explicit Save action.
- Privacy toggles, devices, server details, and support links use the same
  themed native sections. Destructive actions are red rows with confirmations.
- Identity is shown once. Saved, current-device, loading, and error states use
  concise inline text and symbols rather than pills.
- Disconnect, revoke access, and local data removal remain explicit native
  destructive confirmations with clear consequences.

## Motion and haptics

- System navigation, sheet, list, swipe, disclosure, and search transitions are
  primary.
- The authored motion language is short state continuity: mailbox title/count
  crossfade, numeric count transition, cache-status reveal, and successful row
  removal. No staggered entrances, parallax, shimmer, or looping animation.
- Interactive controls may use a subtle press response. Reduce Motion removes
  scale, bounce, and movement and uses a short opacity change.
- Haptics occur after meaningful state completion: send/pair/save success,
  read/star selection, move/archive light impact, destructive confirmation,
  warning, or error. Opening mail, scrolling, typing, and ordinary navigation
  do not trigger custom haptics.

## Spacing and accessibility

- Use an 8-point-derived rhythm, 16-point standard iPhone insets, and at least
  44-point touch targets.
- Mail rows target approximately 82-92 points at standard sizes and grow
  naturally with Dynamic Type.
- Reading and composing measures cap near 720 points on wide screens.
- Preserve VoiceOver order and actions, Dynamic Type, Dark Mode, Increased
  Contrast, Reduce Motion, Reduce Transparency, text selection, keyboard
  avoidance, and the native back gesture.
- At accessibility sizes, content outranks monograms, timestamps, and decorative
  geometry. Labels reflow rather than truncate essential instructions.

## Forbidden patterns

- Bottom tabs, a replacement bottom navigation bar, or action buttons disguised
  as navigation.
- Desktop account rails or three-column shells imposed on iPhone.
- Per-row cards, card stacks, chip gardens, decorative avatar palettes, or
  individual rounded containers around every mail row.
- Fake Liquid Glass, decorative blur, gradients, glows, faux paper, or repeated
  shadows.
- Unsupported mail capabilities presented as actions or status.
- Duplicate titles/actions, gesture-only essential controls, irreversible
  destructive action without confirmation, or color-only state.

## Mailbox state and selection

- Mailbox actions update loaded rows immediately. All selected bulk actions and
  individual archive/trash/delete actions wait five seconds for Undo. Individual
  read/star/restore/unarchive actions commit immediately without an Undo notice. Failures restore affected rows without replacing unrelated rows.
- Reader loads and successful actions update the shared mailbox model directly.
  Revision checks reject list and reader responses superseded by mutations.
- The dock filter menu combines Unread and Starred within the selected mailbox.
  Starred is a filter, not a separate navigation destination. Swipes remain fixed.
- Selection shows its count and Select/Deselect All loaded conversations. Labeled
  bottom bulk controls remain accessible at large text sizes. Individual actions
  leave a lightweight Undo placeholder in the original list position, including
  the last email. Bulk Undo temporarily replaces the entire dock, including Filter and Compose. If an inline action's mailbox is no longer
  visible, its Undo moves to the dock until resolved.
