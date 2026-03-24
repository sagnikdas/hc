# Phase 3 Rollout and Monitoring Runbook

Use this to close the final Phase 3 release checklist items.

## 1) Progressive Rollout

1. Keep `app_config.leaderboard_enabled = 'false'` in production.
2. Release app build to 10% users.
3. Turn on leaderboard:
   ```sql
   update app_config set value = 'true' where key = 'leaderboard_enabled';
   ```
4. Observe 24h ingestion and error metrics.
5. Increase to 50% if healthy for 24h.
6. Increase to 100% if healthy for 48h.

Rollback (instant, no rebuild):

```sql
update app_config set value = 'false' where key = 'leaderboard_enabled';
```

## 2) Ingestion Failure Monitoring

Track edge function status in Supabase Dashboard:
- Functions -> `ingest-listen` -> Logs
- Alert if:
  - 5xx rate > 1% for 10 minutes
  - p95 latency > 1000ms for 10 minutes
  - auth failures spike unexpectedly

Suggested log filters:
- `error`
- `rate_limited`
- `invalid_token`
- `insert failed`

## 3) Leaderboard Query Performance Validation

Run these checks in SQL editor:

```sql
explain analyze
select * from public.leaderboard_top10('all_time');
```

```sql
explain analyze
select * from public.leaderboard_top10('weekly');
```

Run each query 30-50 times at representative data volume. If p95 > 500ms:
- Refresh materialized view:
  ```sql
  select public.refresh_leaderboard();
  ```
- Re-check indexes:
  - `idx_listen_events_completed_at`
  - `idx_listen_events_user_completed_at`

## 4) Phase 2 Dashboard Metrics (ops closeout)

Ensure dashboard charts exist for:
- paywall conversion
- D7 retention
- churn by plan

If using PostHog/Firebase, verify events are being emitted:
- `paywall_viewed`
- `trial_started`
- `subscription_started`
- `subscription_cancelled`

## 5) Exit Criteria

You can mark the remaining checklist items complete only when:
- progressive rollout completed (10% -> 50% -> 100%)
- ingestion alerts configured and tested
- leaderboard p95 < 500ms confirmed
- phase metrics dashboard visible to product owner
