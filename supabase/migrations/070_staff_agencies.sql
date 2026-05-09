-- 070_staff_agencies.sql
-- Staff agency profiles, PSARA/PF/ESI tracking, contract management

BEGIN;

CREATE TABLE staff_agencies (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name            text NOT NULL CHECK (length(name) <= 200),
  type            text NOT NULL CHECK (type IN ('security','housekeeping','gardening','maintenance','multi_service')),
  contact_name    text,                       -- personal data: agency principal contact
  contact_phone   text,                       -- personal data: contact phone
  contact_email   text,
  address         text,

  -- Regulatory compliance
  psara_number    text,                       -- PSARA licence (security agencies only)
  psara_expiry    date,
  pf_number       text,                       -- Provident Fund registration
  esic_number     text,                       -- Employee State Insurance Corporation
  gst_number      text,
  pan_number      text,

  -- Contract
  contract_start  date,
  contract_end    date,
  monthly_rate    numeric(12,2),
  contract_key    text,                       -- GitHub path to signed contract PDF

  is_active       boolean NOT NULL DEFAULT true,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON COLUMN staff_agencies.contact_name  IS 'personal data: agency point-of-contact name';
COMMENT ON COLUMN staff_agencies.contact_phone IS 'personal data: agency contact phone number';
COMMENT ON COLUMN staff_agencies.pan_number    IS 'personal data: agency PAN (used for TDS)';

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE staff_agencies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "agencies_read" ON staff_agencies FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "agencies_manage" ON staff_agencies FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX idx_staff_agencies_society  ON staff_agencies(society_id);
CREATE INDEX idx_staff_agencies_type     ON staff_agencies(type);
CREATE INDEX idx_staff_agencies_active   ON staff_agencies(society_id, is_active);
CREATE INDEX idx_staff_agencies_psara_expiry ON staff_agencies(psara_expiry) WHERE psara_expiry IS NOT NULL;

COMMIT;
