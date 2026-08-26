# QuickMail Design System

<!-- impeccable:product-schema 1 -->

<!--
THESIS: Postmark Desk makes a private mailbox feel like intentional correspondence, replacing generic navigation chrome with one compact mail-first hierarchy.
OWN-WORLD: Crisp semantic paper, ink typography, sage postmark seals, a compact type-led masthead, flat mail rows, and restrained native controls.
STORY: The user immediately sees where they are, what needs attention, and can read, triage, or write without navigating through app chrome.
FIRST VIEWPORT: The active mailbox menu, status, search, Compose, and account identity form one compact masthead above a sender-led stream marked by quiet postmark seals.
FORM: Postmark Desk, rebuilt from live iOS 27 simulator evidence rather than inherited large-title, toolbar-glass, or bottom-sheet conventions.
-->

## Direction

QuickMail is a **Postmark Desk**: a quiet, high-trust place for correspondence
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
- Compose and account/settings are explicit masthead actions. Reply remains the
  only persistent lower-edge action, inside the conversation reader.
- Entering and dismissing Settings must preserve mailbox, search, selection,
  scroll, and draft presentation state.

## Color and material

- **Ink:** the Paper, White, and AMOLED canvases retain the app accent's deep
  indigo family. It owns primary actions and brand punctuation, never a large
  navigation background.
- **Paper:** semantic `systemBackground` for mail and reading content.
- **Canvas:** semantic grouped backgrounds for Settings and secondary flows.
- **Sage:** a muted secondary identity accent for account monograms and rare
  supportive details. It never communicates state by itself.
- **State:** system orange for starred, red for destructive/error, green for
  confirmed success, and semantic secondary text for neutral metadata.
- All light/dark variants use semantic system colors or explicit adaptive
  assets. Text on ink must retain contrast and Increased Contrast support.
- Gradients, glows, faux paper, decorative blur, and ornamental shadows are
  outside the system.
- Genuine Liquid Glass is reserved for interactive floating controls on iOS 26
  and later. iOS 17-25 use native bordered styles, never simulated glass.

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

- A compact semantic masthead contains the visible mailbox menu, concise status,
  44-point search field, Compose, and account access. It replaces the fragile
  system large-title/search-drawer combination.
- Conversations form one flat chronological stream with Today, Yesterday,
  Previous 7 Days, month, and year sections as needed.
- Rows do not use cards. Standard hierarchy is sender and time, subject and
  state symbols, then a one-line preview.
- A 38-point neutral sender monogram with a partial sage postmark arc identifies
  unread mail. Read mail keeps a quiet complete hairline ring. Weight and spoken
  state remain redundant with color.
- Swipe actions, context menus, pull to refresh, pagination, search, loading,
  offline, error, and empty states remain native and fully accessible.
- Cache status is concise and actionable. It states whether saved mail is shown
  and offers Retry only when a refresh failed.
- Compose is a labeled masthead action with a 44-point minimum target. The
  mailbox has no persistent bottom control or reserved bottom inset.

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
- The newest message is expanded. Older messages use native disclosure and
  expand in place with system motion.
- Messages are separated by hairlines and vertical rhythm, never nested cards.
- Plain text, formatted HTML, selection, quoted history, links, attachments,
  Quick Look, and share behavior remain accessible.
- Use a compact, type-led reader masthead instead of the oversized system glass
  toolbar. Star, archive, read state, restore, trash, and permanent deletion
  live in one anchored native menu. Reply remains the sole floating primary
  action.

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

- Pairing is scanner-first. The first screen centers the server-to-phone mail
  illustration with one prominent **Scan QR Code** action. Manual entry is a
  secondary action inside the scanner, where it remains available when camera
  access is denied or scanning is unavailable.
- A compact info action exposes the Privacy Policy before pairing. Support and
  Privacy Policy are also available from the Settings About section.
- The centered onboarding flow preserves Reduce Motion and keeps pairing form
  rows at a 44-point minimum.
- Scanner and manual-entry screens expose a native info action that explains
  where to find the QR code, server URL, and pairing code in QuickMail on the
  web.
- The relationship is described plainly: the code comes from QuickMail on the
  web, HTTPS is required, and the session is kept in Keychain.
- Use one restrained brand moment derived from the iOS identity. Do not build a
  marketing carousel, ornamental hero, or multi-card setup page.
- Camera permission, scanned-host confirmation, errors, progress, and manual
  entry use system sheets, alerts, fields, and controls.

## Settings

- Settings is an inset-grouped native form presented from the account control.
- Information order is account, default sending address, signature, privacy,
  connected devices, and connection controls.
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
  rounded containers around ordinary mail.
- Fake Liquid Glass, decorative blur, gradients, glows, faux paper, or repeated
  shadows.
- Unsupported mail capabilities presented as actions or status.
- Duplicate titles/actions, gesture-only essential controls, irreversible
  destructive action without confirmation, or color-only state.
