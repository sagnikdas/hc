# Phase 2 - Monetization + Growth (Shippable Revenue Start)

## Objective

Introduce monetization and growth loops without degrading trust or devotion flow.

## Pricing and Paywall Setup

- [ ] Define plans:
  - [ ] Monthly premium
  - [ ] Yearly premium (40-60% effective discount)
  - [ ] Optional lifetime
- [ ] Add entitlement model:
  - [ ] `isPremium`
  - [ ] `trialEndsAt`
  - [ ] `planType`
- [ ] Integrate purchase SDK (RevenueCat recommended).
- [ ] Build paywall screen variants (A/B ready).
- [ ] Add restore purchases flow.

## Gating Rules

- [ ] Never gate basic Chalisa playback.
- [ ] Premium gate:
  - [ ] extra voices
  - [ ] advanced analytics
  - [ ] cloud sync (future-ready)
  - [ ] premium ambience/themes

## Conversion Events (Track)

- [ ] `paywall_viewed`
- [ ] `paywall_closed`
- [ ] `trial_started`
- [ ] `subscription_started`
- [ ] `subscription_cancelled`
- [ ] `premium_feature_tapped`

## High-Intent Timing Strategy (Ethical)

- [ ] Show paywall after 3rd completion in a day.
- [ ] Show at milestone unlock moments (11/21/51).
- [ ] Show on premium feature intent (voice/theme select).
- [ ] Show weekly progress reflection CTA.
- [ ] Enforce hard cap: max 1 proactive paywall/day.

## Notification Strategy

- [ ] Morning reminder: 5:30-8:30 AM local.
- [ ] Evening reminder: 7:00-10:00 PM local.
- [ ] Tuesday/Saturday high-priority devotional reminder.
- [ ] Quiet hours respected.

## Growth Loops

- [ ] Referral code and invite flow.
- [ ] Reward logic: unlock one premium voice for 14 days after 3 successful invites.
- [ ] Share card generation after streak milestones.
- [ ] Community onboarding screen with WhatsApp share CTA.

## Non-Breaking Gates

- [ ] Purchase flow fails gracefully (core app still works).
- [ ] Entitlement sync race conditions handled.
- [ ] Conversion analytics visible in dashboard.

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
