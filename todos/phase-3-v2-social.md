# Phase 3 - V2 Social, Leaderboard, and Cloud Sync (Shippable)

## Objective

Add centralized leaderboard and cloud continuity safely.

## Backend Prerequisite

- [ ] Complete `todos/supabase-setup-beginner.md`.
- [ ] Verify Auth + DB + Edge Function pipeline.

## Features

### Auth + Profile

- [ ] Anonymous auth and optional phone/email upgrade.
- [ ] Profile table with display name/avatar.
- [ ] Privacy settings:
  - [ ] show on leaderboard (opt-in)
  - [ ] friends-only visibility (optional)

### Event Sync

- [ ] Queue local completion events offline.
- [ ] Batch sync when online.
- [ ] Retries with backoff and idempotency key.

### Leaderboard

- [ ] Top 10 global list by validated completion count.
- [ ] Weekly and all-time filters.
- [ ] Current user rank highlight.
- [ ] Anti-abuse checks in ingestion function.

### Cloud Backup

- [ ] Sync streak and cumulative counts.
- [ ] Resolve conflict strategy (last-write-wins + server totals for leaderboard counts).

## Non-Breaking Gates

- [ ] If backend unavailable, app still plays and counts locally.
- [ ] No duplicate server events under retry storms.
- [ ] Leaderboard query <500ms p95.

## Testing

- [ ] Offline->online sync with 500 queued events.
- [ ] Multi-device same account conflict test.
- [ ] Edge function auth bypass attempts blocked.

## Release Checklist (Phase Ship)

- [ ] Progressive rollout (10% -> 50% -> 100%).
- [ ] Live monitoring alerts for ingestion failures.
- [ ] Rollback switch for leaderboard feature flag.
- [ ] Commit created only after successful build + run.
- [ ] Suggested commit:
  - [ ] `feat(phase-3): ship v2 social leaderboard and cloud sync`
