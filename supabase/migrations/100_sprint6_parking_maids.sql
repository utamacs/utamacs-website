-- ═══════════════════════════════════════════════════════════════
-- 100_sprint6_parking_maids.sql
-- Sprint 6: insurance doc on parking allocations, KYC expiry on maids
-- ═══════════════════════════════════════════════════════════════

-- ── Parking: insurance document + expiry on allocations ──────────────────────

ALTER TABLE parking_allocations
  ADD COLUMN IF NOT EXISTS insurance_key     text,         -- GitHub doc store path
  ADD COLUMN IF NOT EXISTS insurance_expiry  date;         -- policy expiry date (for alerts)

COMMENT ON COLUMN parking_allocations.insurance_key    IS 'GitHub doc store path — personal data: vehicle insurance document';
COMMENT ON COLUMN parking_allocations.insurance_expiry IS 'Vehicle insurance policy expiry date';

-- Index for expiry alert queries (exec dashboard, cron)
CREATE INDEX IF NOT EXISTS idx_parking_alloc_insurance_expiry
  ON parking_allocations (society_id, insurance_expiry)
  WHERE status = 'active' AND insurance_expiry IS NOT NULL;

-- ── Parking: audit actions extended for insurance + transfer ─────────────────

ALTER TABLE parking_audit
  DROP CONSTRAINT IF EXISTS parking_audit_action_check;

ALTER TABLE parking_audit
  ADD CONSTRAINT parking_audit_action_check
  CHECK (action IN (
    'ALLOCATED','RELEASED','SUSPENDED','REINSTATED',
    'WAITLIST_ADDED','WAITLIST_OFFERED','WAITLIST_ALLOCATED','WAITLIST_WITHDRAWN',
    'INSURANCE_UPLOADED','TRANSFER_REQUESTED','TRANSFER_APPROVED','TRANSFER_REJECTED'
  ));

-- ── Maids: KYC expiry ────────────────────────────────────────────────────────

ALTER TABLE maids
  ADD COLUMN IF NOT EXISTS kyc_expires_at  timestamptz;   -- NULL = no expiry set yet

COMMENT ON COLUMN maids.kyc_expires_at IS 'KYC validity expiry timestamp; NULL means KYC not yet due for renewal';

-- Index for renewal alert queries
CREATE INDEX IF NOT EXISTS idx_maids_kyc_expiry
  ON maids (society_id, kyc_expires_at)
  WHERE is_active = true AND kyc_expires_at IS NOT NULL;

-- Backfill: set kyc_expires_at = verification_date + 365 days for already-verified maids
UPDATE maids
  SET kyc_expires_at = (verification_date + interval '1 year')::timestamptz
  WHERE police_verified = true
    AND verification_date IS NOT NULL
    AND kyc_expires_at IS NULL;

-- Rules engine seed: KYC validity period (days)
INSERT INTO rules (society_id, rule_code, value_type, current_value, description, is_locked)
SELECT
  id,
  'MAID_KYC_VALIDITY_DAYS',
  'integer',
  '365'::jsonb,
  'Number of days a maid KYC verification remains valid before renewal is required',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;
