-- Migration 090: device_push_tokens + feature_flags platform scope
-- Required for native app push notifications and per-platform feature flags.

-- ── device_push_tokens ───────────────────────────────────────────────────────
-- Stores FCM / APNs / Expo push tokens per device. Each user can have multiple
-- devices. Tokens are upserted on every app launch; stale tokens are left in
-- place (the push provider will mark them invalid and we clean up on 410 errors).

CREATE TABLE IF NOT EXISTS device_push_tokens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  profile_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token         text NOT NULL,
  platform      text NOT NULL CHECK (platform IN ('expo', 'fcm', 'apns')),
  app_version   text,
  os_version    text,
  device_model  text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (profile_id, token)
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_profile ON device_push_tokens (profile_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_society  ON device_push_tokens (society_id);

ALTER TABLE device_push_tokens ENABLE ROW LEVEL SECURITY;

-- Members can manage their own tokens only
CREATE POLICY "member_own_push_tokens" ON device_push_tokens
  FOR ALL USING (profile_id = auth.uid());

-- ── feature_flags: platform scope column ─────────────────────────────────────
-- Allows rolling out a module to web only before enabling it on mobile, or
-- enabling a mobile-exclusive feature (e.g. push notifications, QR scan) without
-- showing it in the web nav.

ALTER TABLE feature_flags
  ADD COLUMN IF NOT EXISTS platform text NOT NULL DEFAULT 'all'
  CHECK (platform IN ('all', 'web', 'android', 'ios'));

COMMENT ON COLUMN feature_flags.platform IS
  'Platform scope: all = web + native. Restrict to web/android/ios to roll out gradually.';
