# Hanuman Chalisa App - Phased Implementation Plan (V1 + V2)

This plan is designed so **every phase is shippable** and does not break previous functionality.

## 1) Product Principles

- Keep prayer flow sacred, fast, and low-clutter.
- App should work offline-first; backend only where needed.
- Avoid manipulative dark patterns; use high-intent reminders and clear value.
- Optimize for small app size and smooth performance.

## 2) Tech Stack Recommendation

- Frontend: Flutter (recommended for smooth animation + strong audio plugins).
- Local storage: SQLite (via `sqflite`).
- Backend (v2): Supabase (Auth, Postgres, Edge Functions, Storage).
- Analytics: PostHog or Firebase Analytics.
- Push notifications: Firebase Cloud Messaging.
- Audio: `just_audio` + `audio_service` for background playback.

## 3) Release Phases (All Shippable)

### Phase 0 - Foundation (Shippable Internal Alpha)

Goal: stable app shell + data model + CI + crash-free baseline.

- App shell with 3 tabs: `Play`, `Progress`, `Profile`.
- Theming, typography, localization scaffolding.
- SQLite schema and repository layer.
- Event logging model (`play_started`, `play_completed`, etc.).
- CI: lint, tests, build checks.

Exit criteria:

- App launches reliably on Android + iOS simulator.
- No critical lint/test failures.
- Crash-free basic navigation.

See detailed checklist: `todos/phase-0-foundation.md`.

### Phase 1 - Core Devotional V1 (Public MVP, No Backend Required)

Goal: complete devotional loop + retention basics.

- Preloaded audio (1 voice initially).
- Completion counter increments only when >=95% played.
- Synced lyrics drawer (optional bottom sheet).
- Daily counter + streak + local heatmap.
- Background playback + lockscreen controls.
- Record yourself + loop N times (local only).
- Gentle animations and Hanuman idol art integration.

Exit criteria:

- Completion count accuracy verified.
- Background playback stable across app minimize/restore.
- Offline functionality complete.

See: `todos/phase-1-v1-core.md`.

### Phase 2 - Monetization + Growth Layer (Still Stable, Partial Backend Optional)

Goal: start monetization without harming trust.

- Paywall infrastructure (feature flags, plans, entitlement checks).
- Free vs Premium gating (non-disruptive).
- Referral unlock mechanism.
- Habit reminders (high-intent timing windows).
- Event instrumentation for conversion funnel.
- A/B testing hooks for paywall copy and CTA.

Exit criteria:

- Paywall never blocks core basic prayer flow.
- Entitlement checks deterministic and tested.
- Conversion events visible on dashboard.

See: `todos/phase-2-monetization-growth.md`.

### Phase 3 - V2 Social + Leaderboard + Cloud Sync (Backend Required)

Goal: centralized leaderboard and cross-device continuity.

- Supabase Auth + profile table.
- Listen event ingestion via secure Edge Function.
- Server-validated leaderboard (top 10 global + optional friends).
- Sync local listens when online.
- Basic anti-abuse protections.

Exit criteria:

- Leaderboard shows consistent ranking.
- Sync handles offline backlog correctly.
- Auth and privacy flows are clear and safe.

See: `todos/phase-3-v2-social.md`.

## 4) Monetization Model (Ethical, High Conversion)

### Free Tier

- 1 voice
- Counter, streak, heatmap
- Background playback
- Basic recording loop

### Premium Tier

- Multiple premium voices
- Advanced insights/history
- Sankalp programs and milestone packs
- Cloud sync and cross-device history
- Premium ambience/theme packs

### Optional Revenue Add-ons

- One-time lifetime plan
- Festival bundles
- Donation/support option

## 5) High-Intent Paywall Timing (Not Coercive)

Use these moments to maximize conversion while preserving trust:

- After 3rd completed play in a day (user already engaged).
- At milestone completion (11, 21, 51 plays).
- End of 7-day streak, with continuity framing.
- During setup of premium-only voice/theme.
- At weekly reflection screen ("You completed X this week").

Recommended local reminder windows (user local time):

- Morning devotion window: 5:30-8:30 AM.
- Evening devotion window: 7:00-10:00 PM.
- Tuesday and Saturday: stronger devotional intent; slightly increased reminder priority.

Rules:

- Max 1 paywall impression/day.
- Never show paywall before first successful play completion.
- Never interrupt active chanting.

## 6) Aggressive Acquisition (Fast but Sustainable)

- 21-day Sankalp challenge with social share cards.
- Referral unlocks ("Invite 3 friends to unlock one premium voice for 14 days").
- Temple/community group onboarding kits (WhatsApp-forwardable invite cards).
- Creator collaboration: devotional shorts with app CTA.
- Regional language onboarding and content pages.

## 7) AI-First Build Workflow (Cursor/Claude Token Efficient)

- Build one phase at a time; do not ask AI for huge multi-phase code at once.
- Ask for "one file patch" or "one feature PR-sized change" prompts.
- Keep specs in markdown and refer agent to exact file paths.
- Use checklists and acceptance criteria before generating code.

Prompt template:

```text
You are implementing only Phase X task Y from file <path>.
Constraints:
- Do not touch unrelated files.
- Add tests for changed behavior.
- Keep offline flow intact.
Output:
- Patch only, then list verification commands.
```

## 8) What To Do First (Order)

1. Complete Phase 0 checklist.
2. Build Phase 1 and ship to closed beta users.
3. Add monetization infrastructure in Phase 2.
4. Introduce Supabase and leaderboard in Phase 3.
5. Iterate pricing, copy, and onboarding based on analytics.

## 8.1) Mandatory Stage Completion Protocol

For every phase (`phase-0` to `phase-3`), follow this exact order:

1. Implement all checklist items for the phase.
2. Run full verification (analyze, tests, build).
3. Run the app on device/emulator and complete smoke run.
4. Only if all checks pass, create one phase commit.
5. Generate phase report file before moving to next phase.

Do not proceed to the next phase if the current phase is not passing build and run checks.

Recommended verification command sequence:

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter run -d <device>`

Commit message format:

- `feat(phase-X): complete <phase-name> shippable milestone`

## 9) Supporting Files

- `todos/phase-0-foundation.md`
- `todos/phase-1-v1-core.md`
- `todos/phase-2-monetization-growth.md`
- `todos/phase-3-v2-social.md`
- `todos/supabase-setup-beginner.md`
- `.cursor/skills/hc-build-executor/SKILL.md`
- `.cursor/skills/hc-supabase-setup/SKILL.md`
- `.cursor/skills/hc-growth-monetization/SKILL.md`
- `.cursor/rules/token-efficiency.mdc`
