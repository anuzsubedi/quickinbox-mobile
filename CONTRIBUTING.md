# Contributing to QuickInbox Mobile

Thank you for contributing. QuickInbox Mobile is a two-client monorepo, so every change should make it clear which platform it affects and how it was verified.

## Before you start

1. Read the root README and the README for the affected platform.
2. Search existing issues and pull requests before starting duplicate work.
3. For security-sensitive work, follow SECURITY.md instead of opening a public issue.
4. Confirm that your contribution can be distributed under GPL-3.0-or-later and that new third-party materials have compatible terms.

## Repository structure

- android/ contains the Android Studio/Gradle project.
- ios/ contains the Xcode/SwiftUI project.
- Root documentation describes behavior shared by both clients.
- Platform documentation describes platform-specific commands and conventions.

Do not create a second top-level app directory, duplicate shared documentation, or move platform files merely to make a change appear shared.

## Branches and commits

Use a short feature branch from main, for example:

~~~text
android/fix-pairing-error-state
ios/improve-thread-reader
docs/clarify-server-contract
~~~

Use focused commits with an imperative subject and a conventional type when practical:

~~~text
feat(android): add retry state to pairing
fix(ios): preserve draft recipients
docs: clarify source-offer requirements
test(android): cover malformed pairing payload
~~~

Use your own name and email as the commit author. Do not attribute commits to an editor, coding assistant, bot, or automation tool. Keep unrelated formatting and generated files out of the branch.

## Implementing changes

### Android

- Keep UI in small, state-driven Compose functions.
- Hoist durable state into the appropriate view model or session layer.
- Preserve loading, empty, error, refreshing, and submitting states.
- Keep network access, credential handling, and cache behavior in the data/session layers.
- Add or update tests for domain, API, and view-model behavior where practical.

### iOS

- Keep SwiftUI views focused on presentation and user interaction.
- Keep API, credential, cache, and validation logic in the Core layers.
- Preserve accessibility labels, Dynamic Type, dark appearance, and reduced-motion behavior.
- Treat message HTML as untrusted input and retain the hardened rendering boundary.
- Add or update tests or a reproducible manual verification path for behavior changes.

### Cross-platform behavior

When a change affects a shared product behavior, update both clients or explicitly document why the behavior is platform-specific. Keep endpoint names, payload semantics, error meanings, and security assumptions aligned.

## Testing

Run the checks for each affected client:

~~~sh
cd android
./gradlew test
./gradlew assembleDebug
~~~

~~~sh
cd ios
xcodebuild \
  -project quickinbox/quickinbox.xcodeproj \
  -scheme quickinbox \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath /tmp/quickinbox-ios-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
~~~

If a toolchain is unavailable, say so in the pull request and provide the checks you did complete. Test fresh pairing, session restore, mail loading, threaded reading, compose/send, attachments, errors, and accessibility for relevant changes.

## Pull requests

Every pull request should:

- Explain the user-visible behavior and motivation.
- Identify android, ios, or both in the title or description.
- List the files or layers changed.
- Include tests and manual verification performed.
- Include screenshots only when they materially explain a UI change; do not commit generated screenshot collections.
- Call out API contract changes, migration requirements, security implications, and compatibility risks.
- Update relevant README or protocol documentation when behavior or setup changes.
- Keep credentials, real mail, pairing codes, production URLs, and local IDE state out of the diff.

Maintainers may ask for a smaller scope, platform parity, additional tests, or clearer source/license notices before merging.

## Licensing contributions

Original contributions to the application are accepted for distribution under the repository's GPL-3.0-or-later license. Contributors retain copyright in their contributions unless they separately agree otherwise. Do not submit code, fonts, icons, screenshots, or other materials whose terms you cannot document and redistribute.

The GPL requires distributors of modified covered applications to provide corresponding source and preserve notices. A fork that publishes a modified Android or iOS application must comply with those obligations for the covered work.

## Code of conduct

Be precise, respectful, and constructive. Review code and behavior rather than people. Harassment, discrimination, doxxing, credential sharing, and hostile conduct are not acceptable in project spaces.

