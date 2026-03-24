# Phase 2 - Monetization + Growth (Shippable Revenue Start)

## Objective

Introduce monetization and growth loops without degrading trust or devotion flow.

## Pricing and Paywall Setup

- [x] Define plans:
  - [x] Monthly premium
  - [x] Yearly premium (40-60% effective discount)
  - [x] Optional lifetime
- [x] Add entitlement model:
  - [x] `isPremium`
  - [x] `trialEndsAt`
  - [x] `planType`
- [x] Integrate purchase SDK (RevenueCat recommended).
- [x] Build paywall screen variants (A/B ready).
- [x] Add restore purchases flow.

## Gating Rules

- [x] Never gate basic Chalisa playback.
- [x] Premium gate:
  - [x] extra voices
  - [x] advanced analytics
  - [x] cloud sync (future-ready)
  - [x] premium ambience/themes

## Conversion Events (Track)

- [x] `paywall_viewed`
- [x] `paywall_closed`
- [x] `trial_started`
- [x] `subscription_started`
- [x] `subscription_cancelled`
- [x] `premium_feature_tapped`

## High-Intent Timing Strategy (Ethical)

- [x] Show paywall after 3rd completion in a day.
- [x] Show at milestone unlock moments (11/21/51).
- [x] Show on premium feature intent (voice/theme select).
- [x] Show weekly progress reflection CTA.
- [x] Enforce hard cap: max 1 proactive paywall/day.

## Notification Strategy

- [x] Morning reminder: 5:30-8:30 AM local.
- [x] Evening reminder: 7:00-10:00 PM local.
- [x] Tuesday/Saturday high-priority devotional reminder.
- [x] Quiet hours respected.

## Growth Loops

- [x] Referral code and invite flow.
- [x] Reward logic: unlock one premium voice for 14 days after 3 successful invites.
- [x] Share card generation after streak milestones.
- [x] Community onboarding screen with WhatsApp share CTA.

## Non-Breaking Gates

- [x] Purchase flow fails gracefully (core app still works).
- [x] Entitlement sync race conditions handled.
- [x] Conversion analytics visible in dashboard.

## Release Checklist (Phase Ship)

- [ ] Launch to all users.
- [ ] Monitor:
  - [ ] paywall conversion
  - [ ] D7 retention
  - [ ] churn by plan
- [ ] Iterate paywall copy weekly.
- [ ] Commit created only after successful build + run.
- [ ] Suggested commit:
  - [ ] `feat(phase-2): launch monetization and growth loops`
