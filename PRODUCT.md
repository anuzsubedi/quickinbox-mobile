# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

QuickMail serves people who operate a self-hosted QuickMail account and want a
focused, trustworthy way to read and send their mail from an iPhone. The app
also adapts to iPad without turning the iPhone experience into a reduced desktop
interface.

## Product Purpose

The app makes a self-hosted mailbox feel at home on Apple devices: pair once,
scan the inbox quickly, read full conversations, compose or reply, manage mail,
and control the device session. Success means the interface disappears into
those daily tasks while preserving the user's control over their server.

## Positioning

QuickMail is a native companion to a server the user chooses. Pairing is
explicit, the bearer credential stays in Keychain, and the interface preserves
the direct relationship between the device and that server.

## Operating Context

The primary context is frequent, short sessions on iPhone: checking new mail,
triaging a conversation, replying, and returning to another task. Setup begins
in the QuickMail web app, where the user creates a short-lived QR or manual
pairing code. iPad supports a denser split-view workflow.

## Capabilities and Constraints

- Preserve the existing pairing, mailbox, search, pagination, thread, compose,
  attachment, mail-action, address, signature, device, app-lock, and offline
  cache behavior.
- Minimum deployment is iOS 17.
- Use genuine iOS 26 Liquid Glass APIs only on iOS 26 and later. Older systems
  use the native materials and control conventions mainstream for their OS.
- Navigation, gestures, controls, sheets, alerts, and destructive confirmations
  follow Apple platform conventions.

## Brand Commitments

The product name is QuickMail. Its voice is concise, calm, direct, and
privacy-conscious. The interface should feel intentionally designed rather
than like an untouched SwiftUI template, without sacrificing familiar mail
behaviors.

## Evidence on Hand

The repository contains the working SwiftUI app and its existing production
workflows. No marketing claims, customer proof, or commissioned illustration
assets are available and none should be invented.

## Product Principles

- Content leads; chrome recedes.
- Frequent actions remain immediate and familiar.
- Self-hosting and privacy are explained plainly, never theatrically.
- Distinctive craft comes from hierarchy, rhythm, typography, and purposeful
  material rather than custom replacements for system controls.
- Every state remains useful offline, under failure, and with accessibility
  settings enabled.

## Accessibility & Inclusion

Support Dynamic Type, VoiceOver, semantic colors, increased contrast, Reduce
Motion, 44-point touch targets, and layouts that remain usable at larger text
sizes.
