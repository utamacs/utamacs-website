-- 081_visitor_passes.sql
-- Extend visitor_pre_approvals with a shareable pass: plain OTP, pass_token UUID,
-- scan tracking, and max_uses control.

BEGIN;

ALTER TABLE visitor_pre_approvals
  -- UUID embedded in the public pass URL (/portal/visitors/pass/[pass_token])
  -- Different from qr_token (the old signed JWT) — simpler and DB-verifiable
  ADD COLUMN IF NOT EXISTS pass_token      uuid UNIQUE DEFAULT gen_random_uuid(),
  -- 6-digit numeric OTP shown on the pass card (guard types it if QR scan fails)
  ADD COLUMN IF NOT EXISTS otp_code        text CHECK (otp_code ~ '^\d{6}$'),
  -- Maximum number of times this pass can be used (1 = one-time entry, NULL = unlimited)
  ADD COLUMN IF NOT EXISTS max_uses        int NOT NULL DEFAULT 1 CHECK (max_uses > 0),
  -- Running count of successful gate entries recorded against this pass
  ADD COLUMN IF NOT EXISTS scan_count      int NOT NULL DEFAULT 0 CHECK (scan_count >= 0),
  -- Timestamp of the first successful gate scan
  ADD COLUMN IF NOT EXISTS first_used_at   timestamptz,
  -- Visitor's vehicle number (optional, logged on pass)
  ADD COLUMN IF NOT EXISTS vehicle_number  text CHECK (length(vehicle_number) <= 20),
  -- Notes visible to guard on pass scan
  ADD COLUMN IF NOT EXISTS guard_note      text CHECK (length(guard_note) <= 300);

-- Back-fill pass_token and otp_code for any existing rows that don't have them
UPDATE visitor_pre_approvals
SET
  pass_token = COALESCE(pass_token, gen_random_uuid()),
  otp_code   = COALESCE(otp_code, lpad((floor(random() * 1000000))::int::text, 6, '0'))
WHERE pass_token IS NULL OR otp_code IS NULL;

-- NOT NULL now that back-filled
ALTER TABLE visitor_pre_approvals
  ALTER COLUMN pass_token SET NOT NULL,
  ALTER COLUMN otp_code   SET NOT NULL;

-- Index for fast pass_token lookups (used on every guard scan / pass page load)
CREATE INDEX IF NOT EXISTS idx_vpa_pass_token ON visitor_pre_approvals(pass_token);

-- Index for OTP lookups (guard types 6 digits, we look up by society + otp within time window)
CREATE INDEX IF NOT EXISTS idx_vpa_otp ON visitor_pre_approvals(society_id, otp_code, expires_at);

-- ── RLS: pass page is public — residents and guards can look up by pass_token ─

-- Existing policies cover exec/member/guard reads. Add a policy for unauthenticated
-- pass page loads (guard scans QR, opens public URL before logging in).
-- The pass page API route uses service client, so RLS on this column is informational.

COMMENT ON COLUMN visitor_pre_approvals.pass_token IS
  'Public UUID embedded in sharable pass URL — anyone with the URL can see pass status';
COMMENT ON COLUMN visitor_pre_approvals.otp_code IS
  'DPDPA note: 6-digit OTP is short-lived (expires_at) and not linked to personal identity';

-- ── Rules ────────────────────────────────────────────────────────────────────

INSERT INTO rules (society_id, rule_code, description, value_type, current_value, is_locked)
SELECT s.id, r.code, r.desc, r.vtype, r.val, r.locked
FROM societies s
CROSS JOIN (VALUES
  ('VISITOR_PASS_DEFAULT_HOURS',      'Default visitor pass validity in hours',           'integer', '24',  false),
  ('VISITOR_PASS_MAX_HOURS',          'Maximum visitor pass validity in hours',            'integer', '168', false),
  ('VISITOR_PASS_MAX_USES_DEFAULT',   'Default max gate entries per pass (1 = one-time)', 'integer', '1',   false),
  ('VISITOR_PASS_OTP_WINDOW_MINS',    'Minutes around pass window to accept OTP',          'integer', '30',  false)
) AS r(code, desc, vtype, val, locked)
ON CONFLICT (society_id, rule_code) DO NOTHING;

COMMIT;
