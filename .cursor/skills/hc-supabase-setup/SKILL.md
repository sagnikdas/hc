---
name: hc-supabase-setup
description: Guides step-by-step Supabase setup for auth, schema, RLS, edge functions, and safe app integration for the Hanuman Chalisa app. Use when configuring backend, debugging Supabase auth issues, or enabling leaderboard sync.
---
# HC Supabase Setup

## Purpose

Provide beginner-safe backend setup with secure defaults.

## Runbook

1. Open `todos/supabase-setup-beginner.md`.
2. Complete sections in order; do not skip RLS.
3. Validate each checkpoint before moving on.
4. Keep secrets out of client app bundle.

## Security Rules

- `service_role` key is server-only.
- RLS must be enabled on all user-data tables.
- Edge Function must verify JWT.
- Use idempotency keys for listen event ingestion.

## Debug Checklist

- Auth failures: verify provider enabled + redirect config.
- Insert denied: verify RLS policy conditions.
- Duplicate counts: verify unique `(user_id, session_id)` constraint.
- Empty leaderboard: verify materialized view refresh.
