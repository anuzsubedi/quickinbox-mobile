# QuickInbox iOS App Review preparation

Last audited: August 24, 2026.

This checklist intentionally contains no production URLs, credentials, Apple
IDs, signing team identifiers, or other operator-specific information.

## Current readiness

### Already in the app

- Native SwiftUI app targeting iOS 17 and iPadOS 17.
- App icon variants and the user-facing display name `QuickInbox`.
- Camera and Face ID purpose strings. Camera pairing is optional because the
  server URL and code can also be entered manually.
- HTTPS-only production server validation.
- Bearer credentials stored in Keychain and removable cached mail.
- App Lock, remote-image privacy controls, device revocation, local data wipe,
  and destructive-action confirmation.
- No advertising, analytics, tracking, or third-party iOS SDKs.
- A privacy manifest declaring no tracking and the `UserDefaults` required
  reason `CA92.1`.
- `ITSAppUsesNonExemptEncryption = NO`. QuickInbox uses Apple-provided HTTPS and
  hashing rather than shipping its own non-exempt encryption implementation.

### Release blockers

- [ ] Replace the placeholder bundle ID `com.example.quickinbox` with the final
  App ID registered in the publisher's Apple Developer account.
- [ ] Publish permanent Privacy Policy and Support pages. The support page must
  contain real contact information.
- [ ] Add an easily accessible Privacy Policy link inside the iOS app after its
  permanent URL is known.
- [ ] Finalize and deploy an isolated review server with synthetic mail only.
- [ ] Create a non-admin reviewer identity and a pairing credential that remains
  valid and reusable throughout review. A normal short-lived, single-use code
  is not reliable enough for App Review.
- [ ] Verify the complete reviewer path from a clean install against the live
  review server: manual pairing, QR pairing, inbox, reader, attachment,
  compose/send, reply/forward, search, settings, revoke, and sign out.
- [ ] Decide whether version 1.0 ships on both iPhone and iPad. The target
  currently declares both, so iPad behavior and screenshots are part of the
  submission unless iPad support is deliberately removed.
- [ ] Create the App Store Connect app record, sign an archive with Apple
  Distribution, upload it, and select the processed build for version 1.0.
- [ ] Complete all App Store Connect metadata, privacy, age-rating, content
  rights, export-compliance, availability, pricing, and review-contact fields.

## Privacy decisions

`quickinbox/PrivacyInfo.xcprivacy` declares:

- no tracking;
- no tracking domains;
- no data collected by the app developer for the self-hosted app model; and
- `UserDefaults` access under approved reason `CA92.1`, used for app-local
  preferences such as appearance, selected sending address, and App Lock.

The paired server origin is chosen by the user. The bearer credential remains
in Keychain. The SwiftData inbox cache does not contain the bearer credential
and is cleared when local account data is removed.

Do not publish the App Store Connect privacy answers until the distribution
model is final:

1. **Self-hosted only:** if the publisher and its partners cannot access data on
   paired servers, `Data Not Collected` may match the current binary.
2. **Publisher-operated hosting:** disclose every applicable type that the
   publisher can access, including at least Contact Info, Identifiers, and User
   Content. Reassess Diagnostics if operational logging is enabled.

The review server's synthetic data does not by itself determine the production
privacy label. In either model, answer no to tracking unless cross-company
tracking or advertising is later introduced.

## Review environment

- Use a dedicated HTTPS deployment containing only synthetic users, messages,
  addresses, and attachments.
- Give the reviewer a non-admin identity. Confirm it cannot reach admin screens,
  other users' mail, API-key administration, or deployment controls.
- Make the review pairing code reusable and long-lived, but scoped only to the
  synthetic reviewer. Set an explicit expiry comfortably beyond the expected
  review window.
- Test the supplied QR image and the manual server/code values from a clean
  installation. Keep the backend online and monitor it during review.
- Put the origin and pairing secret only in App Review Information or a review
  attachment, never in Git, screenshots, product-page copy, or the binary.
- Rotate the pairing credential and remove the review environment after review.

## Suggested App Store metadata

These are drafts and must be checked against the final service and policy.

- **Name:** QuickInbox
- **Subtitle:** Private mail, your server
- **Primary category:** Productivity
- **Keywords:** private email,self-hosted,inbox,mail,compose,secure,server
- **Promotional text:** A focused native inbox for your self-hosted QuickInbox
  server.
- **Description:**

  QuickInbox brings your self-hosted QuickInbox inbox to iPhone and iPad. Pair
  securely with your server, read and search conversations, send and reply from
  your configured addresses, work with attachments, and manage connected
  devices from a focused native interface.

  Your server stays in control. QuickInbox connects directly over HTTPS, stores
  its session credential in Keychain, blocks remote email images by default,
  and offers optional App Lock.

  A configured QuickInbox server and account are required.

The product page must not imply that the publisher hosts every user's email,
offers end-to-end encryption, or guarantees security properties that the app
and server do not implement.

## App Review notes template

Replace every bracketed value in App Store Connect. Attach the review QR image
as well as providing manual values so review is not camera-dependent.

> QuickInbox is a native companion for a self-hosted QuickInbox email server. The
> iOS app does not create accounts; server administrators provision them on the
> web. This review identity is non-admin and contains synthetic mail only.
>
> To sign in, tap Continue, then either scan the attached QR code or choose
> Enter Details. Server: [REVIEW SERVER ORIGIN]. Pairing code: [REVIEW CODE].
> The code is reusable for App Review and expires on [DATE].
>
> Camera access is used only to scan the pairing QR and is optional. Face ID is
> requested only if App Lock is enabled in Settings. There are no purchases,
> subscriptions, advertising, analytics, or tracking.
>
> Suggested flow: pair the device; open a synthetic conversation; preview the
> sample attachment; compose a message to [SYNTHETIC RECIPIENT]; then inspect
> Settings for remote-image privacy, App Lock, connected-device revocation, and
> Disconnect This Device.
>
> Account deletion note: this app does not offer account creation. Accounts are
> controlled by the administrator of the paired self-hosted server. Users can
> revoke the iOS session and erase all local app data from Settings.

## App Store Connect checklist

- [ ] Agreements, tax, banking, and Digital Services Act trader status are not
  blocking distribution.
- [ ] App record uses the final bundle ID, SKU, primary language, and category.
- [ ] Version is `1.0`, build number is unique, release mode is intentional, and
  price/territories are selected.
- [ ] Description, subtitle, keywords, copyright, Support URL, Privacy Policy
  URL, and optional Marketing URL are complete and live.
- [ ] App Privacy responses match the final production data flow and all server
  or third-party logging.
- [ ] Age Rating answers acknowledge that QuickInbox displays user email and
  provides person-to-person communication. Do not mark it as Made for Kids.
- [ ] Content Rights confirms the publisher is authorized to provide an email
  client that displays content belonging to the signed-in user.
- [ ] Export compliance matches the binary's HTTPS-only/exempt encryption use.
- [ ] Accessibility claims are published only for features verified across the
  full app. Do not infer a nutrition label from isolated accessibility modifiers.
- [ ] App Review contact details are current. Notes, manual pairing values, and
  a QR attachment are supplied.
- [ ] Highest-resolution required iPhone screenshots use synthetic content. Add
  required iPad screenshots if iPad remains supported. Recommended scenes:
  inbox, conversation, compose, search/mailbox navigation, and privacy settings.
- [ ] The selected build has finished processing and has no privacy-manifest,
  missing-symbol, icon, or export-compliance warnings.
- [ ] Add the version to the draft submission, recheck every field, then choose
  Submit for Review. Merely selecting Add for Review does not submit it.
