# QuickInbox for iOS

A native SwiftUI companion for a self-hosted [QuickInbox](https://github.com/DivinPrince/quickmail) server.

QuickInbox for iOS pairs with a server by QR code or manual code, then provides
native inbox, conversation, compose, search, attachment, privacy, and connected
device experiences on iPhone.

## Requirements

- Xcode 26 or newer
- iPhone running iOS 17 or newer
- A QuickInbox server with the mobile pairing API and migration
  `0012_mobile_pairing.sql`
- Migration `0013_archive.sql` for Archive and Unarchive support

The mobile pairing and archive server extensions have not yet landed on
QuickInbox upstream `main`. A server without those extensions cannot pair with
this app or perform archive actions.

## Build

1. Open `quickinbox/quickinbox.xcodeproj`.
2. Select the `quickinbox` scheme.
3. Confirm the `dev.anuz.quickinbox` bundle identifier and choose your signing
   team locally.
4. Build for an iOS simulator or device.

Command-line compile check:

```sh
xcodebuild \
  -project quickinbox/quickinbox.xcodeproj \
  -scheme quickinbox \
  -sdk iphonesimulator \
  -configuration Release \
  -derivedDataPath /tmp/quickinbox-ios-derived \
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

QuickInbox is available under the MIT License. See [`LICENSE.md`](LICENSE.md).
