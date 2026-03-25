-- ============================================================
-- Phase 3 Social: Profiles, Completions, Leaderboard RPC
-- Run this in the Supabase SQL editor (Dashboard → SQL Editor)
-- ============================================================

-- ── Profiles table ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT,
  email           TEXT,
  phone           TEXT,
  date_of_birth   DATE,
  age             INTEGER,
  referral_code   TEXT UNIQUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS: users can read/write their own row; anyone can read for leaderboard display_name
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own profile"
  ON profiles FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Anyone reads profiles"
  ON profiles FOR SELECT USING (true);

-- ── Completions table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS completions (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  completed_at  TIMESTAMPTZ NOT NULL,
  session_date  DATE NOT NULL,
  count         INTEGER NOT NULL DEFAULT 1,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_completions_user_id       ON completions(user_id);
CREATE INDEX IF NOT EXISTS idx_completions_completed_at  ON completions(completed_at);
CREATE INDEX IF NOT EXISTS idx_completions_session_date  ON completions(session_date);

ALTER TABLE completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users insert own completions"
  ON completions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Anyone reads completions"
  ON completions FOR SELECT USING (true);

-- ── Leaderboard RPC ───────────────────────────────────────────
-- Called from Flutter via: supabase.rpc('get_leaderboard', params: {'p_weekly': true/false})
CREATE OR REPLACE FUNCTION get_leaderboard(p_weekly BOOLEAN DEFAULT false)
RETURNS TABLE (
  rank          BIGINT,
  user_id       UUID,
  display_name  TEXT,
  total_count   BIGINT
) LANGUAGE SQL STABLE AS $$
  SELECT
    RANK() OVER (ORDER BY SUM(c.count) DESC) AS rank,
    c.user_id,
    COALESCE(p.name, 'Devotee')              AS display_name,
    SUM(c.count)                             AS total_count
  FROM completions c
  LEFT JOIN profiles p ON p.id = c.user_id
  WHERE
    CASE WHEN p_weekly
      THEN c.completed_at >= NOW() - INTERVAL '7 days'
      ELSE true
    END
  GROUP BY c.user_id, p.name
  ORDER BY total_count DESC
  LIMIT 10;
$$;

-- Allow anonymous and authenticated users to call the function
GRANT EXECUTE ON FUNCTION get_leaderboard TO anon, authenticated;
