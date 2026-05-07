-- Migration 061: Tenant KYC and Police Verification

CREATE TABLE IF NOT EXISTS tenant_kyc (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  unit_id             uuid NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  profile_id          uuid REFERENCES profiles(id) ON DELETE SET NULL,    -- personal data: SET NULL on deletion

  -- Tenant identity
  full_name           text NOT NULL CHECK (length(full_name) <= 200),     -- personal data: tenant identity
  date_of_birth       date,                                                -- personal data: identity verification
  nationality         text DEFAULT 'Indian' CHECK (length(nationality) <= 100),
  aadhaar_last4       text CHECK (aadhaar_last4 ~ '^[0-9]{4}$'),          -- personal data: last 4 of Aadhaar only
  pan_number          text CHECK (length(pan_number) <= 10),               -- personal data: PAN for tax compliance

  -- Tenancy details
  tenancy_start_date  date NOT NULL,
  tenancy_end_date    date,
  monthly_rent        numeric(10,2),
  agreement_key       text,   -- Supabase storage key for rent agreement PDF

  -- Police verification
  police_verified     boolean NOT NULL DEFAULT false,
  police_station      text CHECK (length(police_station) <= 200),
  verification_date   date,
  verification_ref    text CHECK (length(verification_ref) <= 100),         -- acknowledgement number

  -- Owner
  owner_profile_id    uuid REFERENCES profiles(id) ON DELETE SET NULL,    -- personal data: SET NULL on deletion
  owner_consent       boolean NOT NULL DEFAULT false,
  owner_consent_at    timestamptz,

  -- Workflow
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','submitted','police_verified','completed','expired')),
  notes               text CHECK (length(notes) <= 1000),
  created_by          uuid REFERENCES auth.users(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tenant_kyc_society_unit ON tenant_kyc(society_id, unit_id);
CREATE INDEX IF NOT EXISTS idx_tenant_kyc_status       ON tenant_kyc(society_id, status) WHERE status NOT IN ('completed','expired');
CREATE INDEX IF NOT EXISTS idx_tenant_kyc_profile      ON tenant_kyc(profile_id) WHERE profile_id IS NOT NULL;

ALTER TABLE tenant_kyc ENABLE ROW LEVEL SECURITY;

-- Members can read their own unit's KYC records
CREATE POLICY "member_read_tenant_kyc" ON tenant_kyc FOR SELECT
  USING (
    society_id IN (SELECT p.society_id FROM profiles p WHERE p.id = auth.uid())
    AND (
      profile_id = auth.uid()
      OR owner_profile_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.id = auth.uid()
          AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
      )
    )
  );

-- Exec/admin can manage all KYC records
CREATE POLICY "exec_manage_tenant_kyc" ON tenant_kyc FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid()
      AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
  ));

COMMENT ON TABLE tenant_kyc IS 'Tenant KYC records and police verification status per unit';
COMMENT ON COLUMN tenant_kyc.aadhaar_last4  IS 'personal data: last 4 digits of Aadhaar for identity linking only';
COMMENT ON COLUMN tenant_kyc.pan_number     IS 'personal data: PAN for TDS compliance on rent';
COMMENT ON COLUMN tenant_kyc.full_name      IS 'personal data: tenant name for KYC/police verification';
COMMENT ON COLUMN tenant_kyc.date_of_birth  IS 'personal data: required for police verification form';

-- Register module
INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
SELECT id, 'tenant_kyc', 'Tenant KYC', 22, 'fa-id-card', true
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
