# Phase 2 Conversion Dashboard

This runbook closes: `Conversion analytics visible in dashboard`.

## Data Source

- Table: `public.analytics_events`
- View: `public.phase2_conversion_dashboard`

## App Events Ingested

- `paywall_viewed`
- `paywall_closed`
- `trial_started`
- `subscription_started`
- `subscription_cancelled`
- `premium_feature_tapped`

## Dashboard Queries

Daily conversion table:

```sql
select * from public.phase2_conversion_dashboard limit 30;
```

Funnel totals (last 30 days):

```sql
select
  count(*) filter (where event_name = 'paywall_viewed') as paywall_views,
  count(*) filter (where event_name = 'trial_started') as trials,
  count(*) filter (where event_name = 'subscription_started') as subscriptions,
  count(*) filter (where event_name = 'subscription_cancelled') as cancellations
from public.analytics_events
where created_at >= now() - interval '30 days';
```

## Notes

- Analytics writes are best-effort and never block user flow.
- If Supabase is not configured, analytics gracefully no-op.
