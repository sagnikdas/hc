-- Phase 3 finalize migration: auth/profile, sync, leaderboard, feature flags.
-- Safe to run repeatedly.

create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  leaderboard_opt_in boolean default true,
  friends_only_visibility boolean default false,
  created_at timestamptz default now()
);

alter table profiles
  add column if not exists friends_only_visibility boolean default false;

create table if not exists listen_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id text not null,
  completed_at timestamptz not null default now(),
  source text default 'app',
  unique(user_id, session_id)
);

create table if not exists user_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_streak integer not null default 0,
  best_streak integer not null default 0,
  cumulative_completions integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists app_config (
  key text primary key,
  value text not null
);

insert into app_config (key, value)
values ('leaderboard_enabled', 'true')
on conflict (key) do nothing;

create materialized view if not exists leaderboard_all_time as
select user_id, count(*) as completed_count
from listen_events
group by user_id
order by completed_count desc;

alter table profiles enable row level security;
alter table listen_events enable row level security;
alter table user_stats enable row level security;
alter table app_config enable row level security;

drop policy if exists "read own profile" on profiles;
create policy "read own profile"
on profiles for select
using (auth.uid() = id);

drop policy if exists "update own profile" on profiles;
create policy "update own profile"
on profiles for update
using (auth.uid() = id);

drop policy if exists "insert own profile" on profiles;
create policy "insert own profile"
on profiles for insert
with check (auth.uid() = id);

drop policy if exists "insert own listen events" on listen_events;
create policy "insert own listen events"
on listen_events for insert
with check (auth.uid() = user_id);

drop policy if exists "read own listen events" on listen_events;
create policy "read own listen events"
on listen_events for select
using (auth.uid() = user_id);

drop policy if exists "read own stats" on user_stats;
create policy "read own stats"
on user_stats for select
using (auth.uid() = user_id);

drop policy if exists "insert own stats" on user_stats;
create policy "insert own stats"
on user_stats for insert
with check (auth.uid() = user_id);

drop policy if exists "update own stats" on user_stats;
create policy "update own stats"
on user_stats for update
using (auth.uid() = user_id);

drop policy if exists "public read app_config" on app_config;
create policy "public read app_config"
on app_config for select
using (true);

create or replace function public.leaderboard_top10(period text default 'all_time')
returns table(rank bigint, user_id uuid, display_name text, completed_count bigint)
language plpgsql security definer set search_path = public
as $$
begin
  if period = 'weekly' then
    return query
      select
        row_number() over (order by count(*) desc)::bigint,
        le.user_id,
        coalesce(p.display_name, 'Anonymous')::text,
        count(*)::bigint
      from listen_events le
      left join profiles p on p.id = le.user_id
      where le.completed_at >= now() - interval '7 days'
        and (p.leaderboard_opt_in = true or p.id is null)
        and (coalesce(p.friends_only_visibility, false) = false or p.id is null)
      group by le.user_id, p.display_name
      order by count(*) desc
      limit 10;
  else
    return query
      select
        row_number() over (order by la.completed_count desc)::bigint,
        la.user_id,
        coalesce(p.display_name, 'Anonymous')::text,
        la.completed_count::bigint
      from leaderboard_all_time la
      left join profiles p on p.id = la.user_id
      where (p.leaderboard_opt_in = true or p.id is null)
        and (coalesce(p.friends_only_visibility, false) = false or p.id is null)
      order by la.completed_count desc
      limit 10;
  end if;
end;
$$;

create or replace function public.my_leaderboard_rank(uid uuid, period text default 'all_time')
returns table(rank bigint)
language plpgsql security definer set search_path = public
as $$
begin
  if period = 'weekly' then
    return query
      with ranked as (
        select le.user_id,
               row_number() over (order by count(*) desc)::bigint as r
        from listen_events le
        left join profiles p on p.id = le.user_id
        where le.completed_at >= now() - interval '7 days'
          and (p.leaderboard_opt_in = true or p.id is null)
          and (coalesce(p.friends_only_visibility, false) = false or p.id is null)
        group by le.user_id
      )
      select r from ranked where user_id = uid;
  else
    return query
      with ranked as (
        select la.user_id,
               row_number() over (order by la.completed_count desc)::bigint as r
        from leaderboard_all_time la
        left join profiles p on p.id = la.user_id
        where (p.leaderboard_opt_in = true or p.id is null)
          and (coalesce(p.friends_only_visibility, false) = false or p.id is null)
      )
      select r from ranked where user_id = uid;
  end if;
end;
$$;

create or replace function public.refresh_leaderboard()
returns void
language sql
security definer
set search_path = public
as $$
  refresh materialized view leaderboard_all_time;
$$;
