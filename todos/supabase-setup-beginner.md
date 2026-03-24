# Supabase Setup - Beginner Hand-Holding Guide

Use this only when you start Phase 3.

## 0) Accounts and Tools

- [x] Create Supabase account: <https://supabase.com>
- [x] Install Supabase CLI:
  - macOS: `brew install supabase/tap/supabase`
- [x] Verify: `supabase --version`

## 1) Create Project

- [x] Click "New project".
- [x] Project name: `hanuman-chalisa-app`.
- [ ] Save DB password safely.
- [x] Choose region closest to users.
- [x] Wait until project ready.

## 2) Get Keys and URLs

In Supabase dashboard -> Project Settings -> API:

- [ ] Copy `Project URL`.
- [ ] Copy `anon public key`.
- [ ] Keep `service_role` key secret (never in mobile app).

## 3) Database Schema

Run in SQL editor:

```sql
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  leaderboard_opt_in boolean default true,
  created_at timestamptz default now()
);

create table if not exists listen_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id text not null,
  completed_at timestamptz not null default now(),
  source text default 'app',
  unique(user_id, session_id)
);

create materialized view if not exists leaderboard_all_time as
select user_id, count(*) as completed_count
from listen_events
group by user_id
order by completed_count desc;
```

## 4) Row-Level Security (RLS)

Enable RLS and policies:

```sql
alter table profiles enable row level security;
alter table listen_events enable row level security;

create policy "read own profile"
on profiles for select
using (auth.uid() = id);

create policy "update own profile"
on profiles for update
using (auth.uid() = id);

create policy "insert own listen events"
on listen_events for insert
with check (auth.uid() = user_id);

create policy "read own listen events"
on listen_events for select
using (auth.uid() = user_id);
```

## 5) Auth Setup

Dashboard -> Authentication -> Providers:

- [x] Enable Email OTP (simple start).
- [ ] Optionally enable Phone OTP later.
- [ ] Disable unused providers initially.

## 6) Edge Function for Secure Ingestion

Initialize locally:

- [ ] `supabase login`
- [ ] `supabase link --project-ref <project-ref>`
- [ ] `supabase functions new ingest-listen`

Function responsibilities:

- [x] Verify JWT.
- [x] Validate completion payload.
- [x] Enforce idempotency via `session_id`.
- [x] Insert into `listen_events`.

Deploy:

- [x] `supabase functions deploy ingest-listen --no-verify-jwt=false`

## 7) Mobile App Environment Setup

Keep env values in secure config:

- [x] `SUPABASE_URL`
- [x] `SUPABASE_ANON_KEY`
- [ ] `INGEST_FUNCTION_URL`

Never store:

- [ ] `service_role` key in app bundle.

## 8) Basic Leaderboard Query

Use RPC/view query for top 10:

```sql
select * from leaderboard_all_time limit 10;
```

Refresh materialized view schedule (cron or periodic job):

```sql
refresh materialized view leaderboard_all_time;
```

## 9) Safety Checklist Before Going Live

- [ ] RLS enabled on all user data tables.
- [ ] SQL injection not possible (parameterized queries only).
- [ ] Duplicate session inserts blocked.
- [ ] Rate limiting added at function/API gateway layer.
- [ ] Monitor logs and alerts enabled.

## 10) Rollback Plan

- [ ] Feature flag for leaderboard UI.
- [ ] If backend errors spike, disable leaderboard and keep app local-only.
- [ ] Keep local counting unaffected during outages.
