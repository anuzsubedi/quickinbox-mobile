# QuickInbox for iOS

QuickInbox for iOS is a native SwiftUI client for a self-hosted QuickInbox server. It pairs with the server through a QR code or manually entered pairing details, then provides a focused mail experience on iPhone.

## Features

- QR-first onboarding with manual pairing fallback.
- Strict pairing-payload and server-origin validation.
- Secure credential storage and session restoration.
- Inbox, archive, drafts, sent, and trash mailboxes with combinable Unread and Starred filters.
- Immediate mailbox updates. Individual archive/trash/delete actions offer five-second inline Undo; individual read/star/restore actions commit immediately. Selected bulk actions retain Undo and replace the entire dock.
- Labeled bulk actions, a visible selection count, and select/deselect all loaded conversations.
- Conversation search, threaded reading, quoted-text handling, and hardened HTML rendering.
- Compose, save drafts, send, reply, reply-all, and forward.
- Attachment previews and guarded downloads.
- Signatures, connected-device management, privacy information, and appearance settings.
- Adaptive layouts for compact phones and larger iPhone presentations.
- Offline-friendly mailbox caching and clear loading/error states.

## Requirements

- macOS with Xcode 26 or newer.
- iOS 17 or newer for a device or simulator.
- A QuickInbox server with the mobile pairing API.
- The server migrations and API additions required by the current client, including archive support.

The iOS app is a client, not a mail server. It requires a compatible QuickInbox server to pair and load mail.

The required server code is maintained in the [QuickInbox server repository](https://github.com/DivinPrince/quickinbox). Follow that repository's setup and migration instructions before attempting to pair this client.

## Open and build

1. Open quickinbox/quickinbox.xcodeproj in Xcode.
2. Select the quickinbox scheme.
3. Select a simulator or connected device.
4. Set your own Apple development team and bundle identifier locally if signing is required.
5. Build and run.

The committed project uses a placeholder bundle identifier and contains no development team or signing material. Do not replace those repository-safe values with personal credentials in a commit.

For an unsigned simulator compile check:

~~~sh
xcodebuild \
  -project quickinbox/quickinbox.xcodeproj \
  -scheme quickinbox \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath /tmp/quickinbox-ios-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
~~~

## Project structure

~~~text
quickinbox/
├── App/                         Application/session composition
├── Core/API/                    Requests, date coding, errors, origin checks
├── Core/Auth/                   Credential storage and app lock behavior
├── Core/Cache/                  Mailbox cache
├── Core/Models/                 Account, auth, mail, and pairing models
├── Features/Compose/            Compose, draft, reply, and forward flows
├── Features/Mailbox/            Mailbox list, search, filters, and rows
├── Features/Onboarding/         QR/manual pairing and validation
├── Features/Settings/           Preferences, privacy, signatures, devices
├── Features/Thread/             Thread reader, HTML, quotes, attachments
├── Shared/                      Design system, controls, web view, states
└── Resources/Fonts/             Bundled fonts and their OFL notices
~~~

## API and pairing expectations

The client expects the server to provide a valid pairing payload containing the server origin and pairing code. After pairing, the client uses authenticated API requests for the current user, mailboxes, threads, drafts, sending, actions, attachments, addresses, signatures, and devices.

When changing a request or response model, update the corresponding model, API method, error handling, and UI state. Test malformed origins, expired credentials, empty responses, rate limits, HTML content, attachment failures, and server errors.

## Design and implementation guidance

- Build and test the compact iPhone experience first.
- Prefer system fonts for functional interface text; Bricolage Grotesque is reserved for branding moments.
- Keep hierarchy, one-handed reachability, dynamic type, VoiceOver labels, and reduced-motion behavior in mind.
- Keep network and persistence decisions out of view bodies where practical.
- Treat HTML mail as untrusted input and preserve the existing sanitization boundaries.
- Use the existing shared design primitives before introducing new controls.

## Testing checklist

Before a pull request, verify the affected flow on a simulator or device where possible:

- Fresh install and first-run pairing.
- QR scanning and manual pairing fallback.
- Session restoration and logout.
- Mailbox loading, refresh, search, and empty/error states.
- Thread reading with plain text, HTML, quoted text, and attachments.
- Draft, compose, reply, reply-all, forward, and send failure paths.
- Dynamic Type, VoiceOver labels, dark appearance, and compact layouts.

## Licensing

The original iOS application code is licensed under [GPL-3.0-or-later](LICENSE.md), with the complete license text in the repository root at [../LICENSE](../LICENSE). Bundled fonts remain under the SIL Open Font License 1.1; see the notices beside the font resources and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
