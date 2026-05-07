-- Migration 058: Staff account lifecycle — formal deactivation tracking on profiles

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS deactivated_at  timestamptz,
  ADD COLUMN IF NOT EXISTS deactivation_reason text CHECK (length(deactivation_reason) <= 500);

COMMENT ON COLUMN profiles.deactivated_at       IS 'Timestamp when account was deactivated; NULL means active';
COMMENT ON COLUMN profiles.deactivation_reason  IS 'Reason recorded at deactivation (resignation, contract end, misconduct, etc.)';

CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON profiles(society_id, is_active) WHERE NOT is_active;
