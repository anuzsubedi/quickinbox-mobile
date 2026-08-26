# QuickMail for iOS

A native SwiftUI companion for a self-hosted [QuickMail](https://github.com/DivinPrince/quickmail) server.

QuickMail for iOS pairs with a server by QR code or manual code, then provides
native inbox, conversation, compose, search, attachment, privacy, and connected
device experiences on iPhone.

## Requirements

- Xcode 26 or newer
- iPhone running iOS 17 or newer
- A QuickMail server with the mobile pairing API and migration
  `0012_mobile_pairing.sql`
- Migration `0013_archive.sql` for Archive and Unarchive support

The mobile pairing and archive server extensions have not yet landed on
QuickMail upstream `main`. A server without those extensions cannot pair with
this app or perform archive actions.

## Build

1. Open `quickmail/quickmail.xcodeproj`.
2. Select the `quickmail` scheme.
3. Confirm the `dev.anuz.quickmail` bundle identifier and choose your signing
   team locally.
4. Build for an iOS simulator or device.

Command-line compile check:

```sh
xcodebuild \
  -project quickmail/quickmail.xcodeproj \
  -scheme quickmail \
  -sdk iphonesimulator \
  -configuration Release \
  -derivedDataPath /tmp/quickmail-ios-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The repository intentionally does not contain an Apple development team,
provisioning profiles, App Store Connect credentials, production server URLs,
or private deployment configuration.

## App Store preparation

See [`APP_STORE_PREP.md`](APP_STORE_PREP.md) for the current review checklist,
privacy decisions, metadata draft, and reviewer-access requirements.

## License

QuickMail is available under the MIT License. See [`LICENSE.md`](LICENSE.md).
The bundled Cormorant Garamond font remains under the SIL Open Font License,
Version 1.1. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
