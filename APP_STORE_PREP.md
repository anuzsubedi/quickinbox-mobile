# QuickMail iOS App Review preparation

Last audited: August 24, 2026.

This checklist intentionally contains no production URLs, credentials, Apple
IDs, signing team identifiers, or other operator-specific information.

## Executive status

**Not ready to submit yet.** The native target and core privacy/security
foundations are present, but the App ID registration, public policy/support
pages, in-app Privacy Policy link, review environment, reviewer access, release
archive, product-page assets, and App Store Connect record still need to be
completed. The publisher will host the compatible updated QuickMail server, so
the pairing/archive extensions not being in upstream `main` is not a blocker.

Current local submission-tooling check:

- Xcode 26.6 is installed.
- Apple has required uploads to use Xcode 26 or later with the iOS 26 SDK since
  April 28, 2026.
- This is an upload-toolchain requirement, not the minimum OS users need. An app
  built with the iOS 26 SDK can still have an iOS 17 deployment target.
- Xcode currently discovers one `quickmail` scheme with Debug and Release
  configurations; no shared scheme file is tracked in the repository.
- No App Store archive or upload was created during this documentation audit.

## Current readiness

### Already in the app

- Native SwiftUI app targeting iPhone on iOS 17 or later.
- App icon variants and the user-facing display name `QuickMail`.
- Camera and Face ID purpose strings. Camera pairing is optional because the
  server URL and code can also be entered manually.
- HTTPS-only production server validation.
- Bearer credentials stored in Keychain and removable cached mail.
- App Lock, remote-image privacy controls, device revocation, local data wipe,
  and destructive-action confirmation.
- No advertising, analytics, tracking, or third-party iOS SDKs.
- A privacy manifest declaring no tracking and the `UserDefaults` required
  reason `CA92.1`.
- `ITSAppUsesNonExemptEncryption = NO`. QuickMail uses Apple-provided HTTPS and
  hashing rather than shipping its own non-exempt encryption implementation.

### Release blockers

- [x] Set the Xcode bundle identifier to `dev.anuz.quickmail` for Debug and
  Release.
- [ ] Register the matching explicit App ID `dev.anuz.quickmail` in the
  publisher's Apple Developer account.
- [ ] Confirm the final App ID and signing team are private-fork values only.
  The working tree currently contains a local signing-team change in
  `quickmail/quickmail.xcodeproj/project.pbxproj`; do not publish that value to
  the public upstream repository.
- [ ] Publish permanent Privacy Policy and Support pages. The support page must
  contain real contact information.
- [ ] Add an easily accessible Privacy Policy link inside the iOS app after its
  permanent URL is known.
- [ ] Finalize and deploy an isolated review server with synthetic mail only.
- [ ] Deploy the publisher-hosted server with the mobile-pairing and
  Archive/Unarchive migrations and APIs required by `README.md`. Upstream
  inclusion is not required for this distribution model.
- [ ] Create a non-admin reviewer identity and a pairing credential that remains
  valid and reusable throughout review. A normal short-lived, single-use code
  is not reliable enough for App Review.
- [ ] Verify the complete reviewer path from a clean install against the live
  review server: manual pairing, QR pairing, inbox, reader, attachment,
  compose/send, reply/forward, search, settings, revoke, and sign out.
- [x] Limit the target to iPhone with a consistent iOS 17.0 deployment target
  for Debug and Release.
- [ ] Create the App Store Connect app record, sign an archive with Apple
  Distribution, upload it, and select the processed build for version 1.0.
- [ ] Complete all App Store Connect metadata, privacy, age-rating, content
  rights, export-compliance, availability, pricing, and review-contact fields.

## Privacy decisions

`quickmail/PrivacyInfo.xcprivacy` declares:

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

- **Name:** QuickMail
- **Subtitle:** Private mail, your server
- **Primary category:** Productivity
- **Keywords:** private email,self-hosted,inbox,mail,compose,secure,server
- **Promotional text:** A focused native inbox for your self-hosted QuickMail
  server.
- **Description:**

  QuickMail brings your self-hosted QuickMail inbox to iPhone. Pair
  securely with your server, read and search conversations, send and reply from
  your configured addresses, work with attachments, and manage connected
  devices from a focused native interface.

  Your server stays in control. QuickMail connects directly over HTTPS, stores
  its session credential in Keychain, blocks remote email images by default,
  and offers optional App Lock.

  A configured QuickMail server and account are required.

The product page must not imply that the publisher hosts every user's email,
offers end-to-end encryption, or guarantees security properties that the app
and server do not implement.

## App Review notes template

Replace every bracketed value in App Store Connect. Attach the review QR image
as well as providing manual values so review is not camera-dependent.

> QuickMail is a native companion for a self-hosted QuickMail email server. The
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
- [ ] The Apple Developer Program membership is active, the account compliance
  review has no pending request, and the current agreements show `Active`.
- [ ] App record uses the final bundle ID, SKU, primary language, and category.
- [ ] Version is `1.0`, build number is unique, release mode is intentional, and
  price/territories are selected.
- [ ] Description, subtitle, keywords, copyright, Support URL, Privacy Policy
  URL, and optional Marketing URL are complete and live.
- [ ] App Privacy responses match the final production data flow and all server
  or third-party logging.
- [ ] Age Rating answers acknowledge that QuickMail displays user email and
  provides person-to-person communication. Do not mark it as Made for Kids.
- [ ] Content Rights confirms the publisher is authorized to provide an email
  client that displays content belonging to the signed-in user.
- [ ] Export compliance matches the binary's HTTPS-only/exempt encryption use.
- [ ] Accessibility claims are published only for features verified across the
  full app. Do not infer a nutrition label from isolated accessibility modifiers.
- [ ] App Review contact details are current. Notes, manual pairing values, and
  a QR attachment are supplied.
- [ ] Highest-resolution required iPhone screenshots use synthetic content.
  Recommended scenes: inbox, conversation, compose, search/mailbox navigation,
  and privacy settings.
- [ ] The selected build has finished processing and has no privacy-manifest,
  missing-symbol, icon, or export-compliance warnings.
- [ ] Add the version to the draft submission, recheck every field, then choose
  Submit for Review. Merely selecting Add for Review does not submit it.

## Ordered release runbook

### 1. Close product and legal blockers

- [ ] Register the explicit App ID `dev.anuz.quickmail` and use it in the App
  Store Connect record.
- [ ] Publish Privacy Policy and Support URLs, then add the Privacy Policy link
  inside Settings. Apple's privacy guideline requires the link both in App
  Store Connect and in an easily accessible location inside the app.
- [ ] Freeze the compatible server API/migration version used by the release.
- [ ] Decide whether QuickMail is free or paid. Banking and tax setup is needed
  for paid distribution; do not add non-Apple purchase calls to action without
  a separate App Review/payment-policy assessment.

### 2. Prepare the binary

- [ ] Set `MARKETING_VERSION` to the public version and increment
  `CURRENT_PROJECT_VERSION` for every upload.
- [ ] Set the final bundle ID and Automatic Signing team for both Debug and
  Release without committing personal signing values to an upstream branch.
- [ ] In **Manage Schemes**, mark `quickmail` as Shared if archives will be
  produced by CI or another checkout, and commit only the non-personal shared
  scheme file.
- [ ] Confirm Release keeps only intended features and contains no debug menu,
  mock server, placeholder URL, sample credential, or private review secret.
- [ ] Build the Release target with the App Store toolchain:

  ```sh
  xcodebuild \
    -project quickmail/quickmail.xcodeproj \
    -scheme quickmail \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath /tmp/QuickMail.xcarchive \
    archive
  ```

- [ ] In Xcode Organizer, run **Validate App** on the archive, resolve every
  error and relevant warning, then choose **Distribute App > App Store Connect
  > Upload**. Validation alone is not an upload.
- [ ] Wait for processing to complete and answer any export-compliance prompt.
  A successfully processed build should not be confused with an approved app.

### 3. Prepare App Review access

- [ ] Keep the dedicated HTTPS review backend online for the complete review
  window and seed it only with synthetic identities, messages, recipients, and
  attachments.
- [ ] Supply a fully functional non-admin demo identity plus a sample QR code
  and manual pairing values. The access method must survive a reinstall or a
  reviewer retry; use a narrowly scoped review-only mechanism rather than an
  ordinary one-time production pairing code.
- [ ] From a clean device, manually verify onboarding, camera denial/manual
  entry, inbox/search, conversation HTML, remote-image opt-in, attachment
  preview/share, compose/send, reply/forward, mail actions, offline cache,
  App Lock, device revocation, local wipe, and disconnect.
- [ ] Confirm all links and backend features work over public internet without
  VPN, local DNS, allow-listed personal IPs, or developer intervention.

### 4. Build the product page

- [ ] Create the App Store Connect app record before the first upload.
- [ ] Complete the metadata and privacy decisions in this document.
- [ ] Upload one to ten screenshots per required device family, with no alpha
  channel, using synthetic mail. If the UI is consistent across sizes, Apple
  permits the highest-resolution required screenshots to scale down.
- [ ] Attach the review QR image and paste the final review notes. Test the
  supplied values once more without consuming or invalidating reviewer access.

### 5. Submit and release

- [ ] Select the processed build, choose price/tax category and territories,
  select manual, automatic, or phased release, then click **Add for Review**.
- [ ] Open the draft submission and click **Submit for Review**. `Ready for
  Review` means the item is only in a draft; `Waiting for Review` confirms Apple
  received the submission.
- [ ] Monitor App Review messages and keep the review backend and credentials
  working until the submission is accepted and released.
- [ ] After release, rotate/remove review access, tag the exact shipped commit,
  save the archive/dSYMs securely, and document the live version/build.

## Official Apple references

- [Upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Create an app record and App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- [Required app and version properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Screenshot upload guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Agreement status](https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/)
