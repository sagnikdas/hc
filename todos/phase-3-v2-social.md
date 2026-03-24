# Phase 3 - V2 Social, Leaderboard, and Cloud Sync (Shippable)

## Objective

Add centralized leaderboard and cloud continuity safely.

## Backend Prerequisite

- [x] Complete `todos/supabase-setup-beginner.md`.
- [x] Verify Auth + DB + Edge Function pipeline.

## Features

### Auth + Profile

- [x] Anonymous auth and optional phone/email upgrade.
- [x] Profile table with display name/avatar.
- [x] Privacy settings:
  - [x] show on leaderboard (opt-in)
  - [x] friends-only visibility (optional)

### Event Sync

- [x] Queue local completion events offline.
- [x] Batch sync when online.
- [x] Retries with backoff and idempotency key.

### Leaderboard

- [x] Top 10 global list by validated completion count.
- [x] Weekly and all-time filters.
- [x] Current user rank highlight.
- [x] Anti-abuse checks in ingestion function.

### Cloud Backup

- [x] Sync streak and cumulative counts.
- [x] Resolve conflict strategy (last-write-wins + server totals for leaderboard counts).

## Non-Breaking Gates

- [x] If backend unavailable, app still plays and counts locally.
- [x] No duplicate server events under retry storms.
- [ ] Leaderboard query <500ms p95.

## Testing

- [x] Offline->online sync with 500 queued events.
- [x] Multi-device same account conflict test.
- [x] Edge function auth bypass attempts blocked.

## Release Checklist (Phase Ship)

- [ ] Progressive rollout (10% -> 50% -> 100%).
- [ ] Live monitoring alerts for ingestion failures.
- [x] Rollback switch for leaderboard feature flag.
- [ ] Commit created only after successful build + run.
- [ ] Suggested commit:
  - [ ] `feat(phase-3): ship v2 social leaderboard and cloud sync`
