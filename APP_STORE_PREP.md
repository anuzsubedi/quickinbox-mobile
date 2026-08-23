# QuickMail App Store preparation

This file records the privacy decisions that must be verified before the iOS
app is submitted. It intentionally contains no production URLs, credentials,
Apple IDs, team identifiers, or other operator-specific information.

## Privacy manifest

`quickmail/PrivacyInfo.xcprivacy` declares:

- no tracking;
- no tracking domains;
- no data collected by the app developer for the self-hosted app model; and
- `UserDefaults` access under approved reason `CA92.1`, used only for app-local
  preferences such as the selected sending address and biometric-lock setting.

The app does not include analytics or advertising SDKs. The paired server
origin is chosen by the user, and the bearer credential remains in Keychain.
The SwiftData inbox cache does not contain the bearer credential and is cleared
when local account data is removed.

## App Store Connect privacy answers

Do not submit the privacy nutrition-label answers until the review deployment
model is final:

1. **Self-hosted only:** if the publisher cannot access any paired server,
   selecting **Data Not Collected** is consistent with the current binary.
2. **Publisher-operated demo or hosted service:** data sent to that service may
   count as developer collection. Reassess at least Contact Info (email
   address/name), Identifiers (user ID), User Content (emails/attachments), and
   Diagnostics before answering App Store Connect.

In both cases, answer **No** to tracking unless the product later adds
cross-company tracking or advertising behavior.

## Review deployment checklist

- Use a dedicated demo environment containing synthetic messages only.
- Create a least-privilege reviewer account; never reuse a personal account.
- Put the demo URL and credentials only in App Review notes or another approved
  secret channel, never in Git.
- Rotate or delete review credentials after review.
- Confirm the demo account cannot access admin screens or other users' mail.

## Submission items still requiring owner action

- Finalize and deploy the isolated demo environment.
- Enter the verified privacy answers in App Store Connect.
- Capture required screenshots using synthetic content.
- Upload a signed build to TestFlight and complete beta review details.
