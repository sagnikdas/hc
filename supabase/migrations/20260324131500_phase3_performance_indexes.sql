-- Phase 3 performance/index hardening for leaderboard queries.
-- Safe to re-run.

create index if not exists idx_listen_events_completed_at
  on public.listen_events (completed_at desc);

create index if not exists idx_listen_events_user_completed_at
  on public.listen_events (user_id, completed_at desc);
