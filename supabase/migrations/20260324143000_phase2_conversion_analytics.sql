-- Phase 2 conversion analytics storage and dashboard view.
-- Safe to run repeatedly.

create table if not exists public.analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  event_name text not null,
  event_params jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_analytics_events_event_name_created_at
  on public.analytics_events (event_name, created_at desc);

create index if not exists idx_analytics_events_created_at
  on public.analytics_events (created_at desc);

alter table public.analytics_events enable row level security;

drop policy if exists "insert analytics events" on public.analytics_events;
create policy "insert analytics events"
on public.analytics_events
for insert
with check (auth.uid() = user_id or user_id is null);

drop policy if exists "service role read analytics events" on public.analytics_events;
create policy "service role read analytics events"
on public.analytics_events
for select
using (auth.role() = 'service_role');

create or replace view public.phase2_conversion_dashboard as
select
  date_trunc('day', created_at) as day,
  count(*) filter (where event_name = 'paywall_viewed') as paywall_viewed,
  count(*) filter (where event_name = 'trial_started') as trial_started,
  count(*) filter (where event_name = 'subscription_started') as subscription_started,
  count(*) filter (where event_name = 'subscription_cancelled') as subscription_cancelled,
  case
    when count(*) filter (where event_name = 'paywall_viewed') = 0 then 0
    else round(
      100.0 * (count(*) filter (where event_name = 'subscription_started'))::numeric
      / (count(*) filter (where event_name = 'paywall_viewed')),
      2
    )
  end as paywall_to_subscribe_conversion_pct
from public.analytics_events
group by 1
order by 1 desc;
