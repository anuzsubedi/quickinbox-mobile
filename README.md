# QuickInbox Mobile

Native Android and iOS clients for [QuickInbox](https://github.com/DivinPrince/quickinbox), a self-hosted email experience.

QuickInbox Mobile is designed around a simple idea: the server owns the mail and the user owns the connection. The mobile clients pair with a QuickInbox server, keep credentials in the platform secure store, and provide a focused experience for reading, organizing, and composing mail.

## What is in this repository

~~~text
quickinbox-mobile/
├── android/                 Jetpack Compose Android application
├── ios/                     SwiftUI iOS application
├── CONTRIBUTING.md          Development and pull-request policy
├── SECURITY.md              Private security-reporting guidance
├── THIRD_PARTY_NOTICES.md   Fonts and dependency licensing notes
└── LICENSE                  GNU GPLv3-or-later for original app code
~~~

The Android and iOS histories were brought together under their platform directories. Platform-specific files remain platform-specific; a change that affects both clients should be implemented and reviewed in both directories rather than hiding platform behavior behind an artificial shared layer.

## Product capabilities

Both clients support the core QuickInbox mobile workflow:

- Pair with a server using a QR code or manually entered pairing details.
- Validate pairing origins and pairing payloads before connecting.
- Restore a saved session securely on launch.
- Browse inbox, archive, starred, drafts, sent, and trash mailboxes.
- Search and filter conversation lists.
- Read threaded messages with sanitized HTML rendering and quoted-text handling.
- Compose, save drafts, send, reply, reply-all, and forward messages.
- Attach and download files with size and filename safeguards.
- Manage signatures, connected devices, privacy information, and appearance preferences.
- Cache selected mailbox data for a more resilient mobile experience.

Exact behavior can differ where Android and iOS platform conventions require it.

## Server compatibility

The apps are clients for the [QuickInbox server project](https://github.com/DivinPrince/quickinbox), a self-hosted mail server. They are not standalone mail servers and do not replace the server's SMTP, IMAP, storage, authentication, or administration responsibilities.

The server must expose the mobile pairing and mail APIs used by the clients. The current clients use endpoints for pairing, current-user lookup, mailbox/thread retrieval, drafts, sending, replies, forwarding, attachments, mailbox actions, addresses/signatures, and connected-device management. Keep the server and client versions compatible when changing API contracts.

## Quick start

1. Clone the repository.
2. Read the platform README for the client you want to run:
   - [Android development guide](android/README.md)
   - [iOS development guide](ios/README.md)
3. Run a compatible QuickInbox server and obtain its pairing QR code or pairing details.
4. Build and launch the selected client.
5. Pair from the onboarding screen.

No production server URL, signing credential, Apple development team, or personal deployment configuration belongs in this repository.

## Source layout

### Android

The Android client uses Kotlin, Jetpack Compose, Material 3, OkHttp, Gson, CameraX, and ML Kit barcode scanning. Network and persistence code lives under android/app/src/main/java/dev/anuz/quickinbox/data; domain models and pairing validation live under domain; UI features are grouped under ui.

### iOS

The iOS client uses SwiftUI and Apple platform frameworks. API, authentication, caching, and models live under ios/quickinbox/quickinbox/Core; user-facing features live under Features; shared design and controls live under Shared.

## Repository hygiene

Do not commit:

- Build output, derived data, IDE user state, or test-result bundles.
- Signing certificates, provisioning profiles, private keys, tokens, or deployment credentials.
- Real user mail, pairing codes, server secrets, or production URLs.
- Generated screenshots or release-submission material.
- Machine-specific configuration that other contributors cannot reproduce.

The root and platform .gitignore files cover common generated files, but every contributor is responsible for checking the diff before committing.

## Licensing

Original QuickInbox Mobile application code is licensed under the [GNU General Public License, version 3 or any later version](LICENSE). The same license applies to the Android and iOS app code; platform-specific notices are in [android/LICENSE.md](android/LICENSE.md) and [ios/LICENSE.md](ios/LICENSE.md).

GPLv3-or-later permits commercial distribution, but a distributor of a modified app must provide the corresponding source code and preserve the required notices. This repository does not grant rights to QuickInbox names, logos, trademarks, third-party fonts, or third-party dependencies. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Contributions should be scoped, tested on the affected platform, documented when behavior changes, and submitted with the appropriate GPL and third-party notices.

## Security

Do not disclose security vulnerabilities in public issues. Follow [SECURITY.md](SECURITY.md) for the reporting process and the information to include.

## License and attribution note

This repository contains preserved histories from the Android and iOS source projects. Copyright notices and license notices that belong to third-party materials remain applicable. If you redistribute a build or fork, review the complete license and notices before distribution.
