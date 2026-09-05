# QuickInbox for Android

QuickInbox for Android is a Kotlin and Jetpack Compose client for a self-hosted QuickInbox server. It is designed for a compact phone workflow: pair once, restore securely, and keep the inbox close at hand.

## Features

- QR-first onboarding with manual pairing fallback.
- Pairing-origin and payload validation before authentication.
- Secure credential storage and persisted session restoration.
- Inbox, archive, starred, drafts, sent, and trash mailboxes.
- Search, filters, date grouping, bulk mailbox actions, and refresh.
- Threaded reading with hardened HTML and quoted-content handling.
- Compose, drafts, send, reply, reply-all, forward, and attachments.
- Attachment downloads with bounded size and safe filename handling.
- Signatures, connected devices, privacy information, and appearance settings.
- Light/dark theme support, expressive motion, and accessibility-conscious controls.
- Mailbox caching for a more resilient return to the app.
- Optional navigation dock: enable **Show navigation dock** in Appearance for Inbox, Archive, Sent, Drafts, and Trash; turn it off to use the side drawer. The dock stays visible in every mailbox, and Back returns to Inbox.

## Requirements

- Android Studio with a current Android SDK.
- JDK 11 for the configured Gradle/Kotlin toolchain.
- Android SDK 37 for compilation and target API 37.
- Android 7.0 / API 24 or newer for the minimum supported device.
- A QuickInbox server with the mobile pairing and mail APIs.

The Android app is a client, not a mail server. It cannot operate without a compatible QuickInbox server after onboarding.

The required server code is maintained in the [QuickInbox server repository](https://github.com/DivinPrince/quickinbox). Use the server's documented setup and migration instructions before attempting to pair this client.

## Open and run

1. Open the `android/` directory in Android Studio.
2. Allow Gradle to sync dependencies.
3. Select an emulator or connected Android device.
4. Run the `app` configuration.
5. Pair with a server using its QR code or manual pairing details.

The committed application ID is a repository-safe development value. Configure any release signing outside the repository and never commit keystores, passwords, tokens, or local deployment files.

## Command-line checks

From this directory:

```sh
./gradlew test
```

For a local debug build:

```sh
./gradlew assembleDebug
```

Use a configured JDK 11 installation if Gradle cannot find Java. Generated `build/` output is intentionally ignored.

## UI dependencies

The app uses the stable Compose BOM `2026.08.00` with Material 3 explicitly pinned to
`1.5.0-alpha27` for Google's native expressive pull-to-refresh loading indicator.
The Compose compiler plugin is `2.3.21`. Material 3 is a prerelease dependency;
review its release notes and rerun UI compatibility checks when upgrading it.
The app uses `MaterialExpressiveTheme` globally for expressive component defaults
and motion, retaining its custom color palettes and Google Sans typography. Android support remains API 24 and newer,
with compile/target SDK 37.

## Project structure

```text
app/src/main/java/dev/anuz/quickinbox/
├── data/               API client, credentials, cache, preferences, sessions
├── domain/             Mail models, pairing validation, dates, actions
├── ui/
│   ├── onboarding/     First-run welcome and pairing entry points
│   ├── pairing/        Manual and confirmed pairing flows
│   ├── scanner/        CameraX and ML Kit QR scanning
│   ├── mailbox/        Mailbox list, search, filters, and selection
│   ├── thread/         Thread reading, HTML, quotes, and attachments
│   ├── compose/        Compose, drafts, replies, forwards, and recipients
│   ├── settings/       Preferences, privacy, devices, and signatures
│   └── theme/          Color, typography, motion, and theme state
└── res/                Icons, onboarding artwork, fonts, themes, and strings
```

## API and data handling

The API layer uses the server origin captured during pairing and authenticated requests for current-user data, mailboxes, threads, drafts, sending, actions, attachments, addresses, signatures, and connected devices. Keep origin validation and credential handling intact when changing networking code.

When changing a server model or endpoint, update the Kotlin model, API method, loading/error state, cache behavior, and relevant UI. Exercise malformed payloads, expired credentials, rate limits, empty mailboxes, HTML mail, attachment failures, and offline transitions.

## Compose guidance

- Favor small, previewable composables and state hoisted into view models.
- Keep screen state explicit for loading, empty, error, refreshing, and submitting states.
- Preserve one-handed reachability and content hierarchy on compact screens.
- Use semantic content descriptions and test larger font scales.
- Keep HTML mail untrusted and inside the existing sanitization path.
- Reuse the existing theme, motion, haptics, and mail components before adding new primitives.

## Testing checklist

Before a pull request, verify the affected flow on an emulator or device where possible:

- Fresh install, QR pairing, and manual pairing fallback.
- Session restore, logout, and credential failure.
- Mailbox loading, refresh, search, filters, bulk actions, and empty states.
- Thread reading with plain text, HTML, quoted text, and attachments.
- Draft, compose, reply, reply-all, forward, send, and failure paths.
- Dark theme, large font scale, TalkBack labels, rotation, and compact widths.

## Licensing

The original Android application code is licensed under [GPL-3.0-or-later](LICENSE.md), with the complete license text in the repository root at [../LICENSE](../LICENSE). Bundled fonts remain under the SIL Open Font License 1.1; see `app/src/main/assets/fonts/OFL.txt` and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
