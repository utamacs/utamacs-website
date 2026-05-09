-- Migration 063: Byelaw Memberships + Staff KYC enhancements
-- Byelaw Ch.4: one registered member per flat; admission fee ₹1000 + share capital ₹1000
-- Byelaw Ch.13: security pass for maids/staff requires Aadhaar + 2 photos

-- ── Memberships table ─────────────────────────────────────────────────────────
-- One formal society membership per flat (byelaw 4.1, 4.4)
-- First-named person on sale deed = the sole member; joint owners sign NOC

CREATE TABLE IF NOT EXISTS memberships (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id                uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  unit_id                   uuid NOT NULL REFERENCES units(id),
  profile_id                uuid REFERENCES profiles(id) ON DELETE SET NULL,  -- personal data: SET NULL on deletion (DPDPA)

  -- Member identity at time of registration (preserved even if profile deleted)
  member_name               text NOT NULL CHECK (length(member_name) BETWEEN 2 AND 100),
  member_type               text NOT NULL DEFAULT 'original_owner'
                              CHECK (member_type IN ('original_owner','purchaser','successor','heir','joint_owner_nominee')),
  joint_owner_names         text[] DEFAULT '{}',  -- co-owner names for NOC tracking

  -- Proof of ownership (byelaw 4.1, 4.2)
  sale_deed_key             text,               -- Supabase Storage: member-documents bucket
  sale_deed_number          text CHECK (length(sale_deed_number) <= 100),
  sale_deed_date            date,
  registration_office       text CHECK (length(registration_office) <= 200),

  -- Byelaw financial requirements (byelaw 4.1)
  admission_fee_amount      numeric(10,2) NOT NULL DEFAULT 1000.00,
  admission_fee_paid        boolean NOT NULL DEFAULT false,
  admission_fee_paid_at     timestamptz,
  admission_fee_receipt_no  text CHECK (length(admission_fee_receipt_no) <= 100),

  share_capital_amount      numeric(10,2) NOT NULL DEFAULT 1000.00,
  share_capital_paid        boolean NOT NULL DEFAULT false,
  share_capital_paid_at     timestamptz,

  byelaw_copy_fee_paid      boolean NOT NULL DEFAULT false,  -- ₹250 optional

  -- Share certificate (byelaw 4.12 — signed by President + Secretary)
  share_certificate_number  text UNIQUE CHECK (length(share_certificate_number) <= 30),
  share_certificate_issued_at timestamptz,
  share_certificate_key     text,               -- Supabase Storage: member-documents bucket (PDF)

  -- Membership identifier
  membership_number         text UNIQUE CHECK (length(membership_number) <= 30),

  -- Status state machine
  -- applied → fees_pending → fees_confirmed → approved → (suspended | transferred | deceased)
  status                    text NOT NULL DEFAULT 'applied'
                              CHECK (status IN ('applied','fees_pending','fees_confirmed','approved','suspended','transferred','deceased','rejected')),

  -- Voting eligibility (byelaw 4.6, 4.16) — re-evaluated against dues
  voting_eligible           boolean NOT NULL DEFAULT false,
  voting_disqualified_reason text CHECK (length(voting_disqualified_reason) <= 300),

  -- Declaration signed (byelaw 4.7)
  declaration_signed        boolean NOT NULL DEFAULT false,
  declaration_signed_at     timestamptz,

  -- Approval workflow
  submitted_at              timestamptz,
  reviewed_by               uuid REFERENCES profiles(id) ON DELETE SET NULL,  -- personal data: SET NULL (DPDPA)
  reviewed_at               timestamptz,
  rejection_reason          text CHECK (length(rejection_reason) <= 500),

  -- Membership end
  effective_to              date,
  termination_reason        text CHECK (length(termination_reason) <= 300),

  created_at                timestamptz NOT NULL DEFAULT now()
);

-- One active/pending membership per unit — enforces byelaw 4.4 one-per-flat rule
CREATE UNIQUE INDEX IF NOT EXISTS memberships_unit_one_active
  ON memberships(unit_id)
  WHERE status NOT IN ('rejected', 'transferred', 'deceased');

CREATE INDEX IF NOT EXISTS idx_memberships_society_status
  ON memberships(society_id, status);

CREATE INDEX IF NOT EXISTS idx_memberships_profile
  ON memberships(profile_id);

COMMENT ON COLUMN memberships.profile_id IS 'DPDPA personal data: links to portal user profile; SET NULL on deletion';
COMMENT ON COLUMN memberships.member_name IS 'DPDPA personal data: first-named owner as per sale deed';
COMMENT ON COLUMN memberships.sale_deed_key IS 'DPDPA personal data: storage key for sale deed document in member-documents bucket';

ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;

-- Members can view their own society's memberships (to see their unit's status)
CREATE POLICY "member_read_memberships" ON memberships FOR SELECT
  USING (
    society_id IN (SELECT p.society_id FROM profiles p WHERE p.id = auth.uid())
    AND (
      profile_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.id = auth.uid()
          AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
      )
    )
  );

-- Exec/admin manage all memberships
CREATE POLICY "exec_manage_memberships" ON memberships FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
        AND p.society_id = memberships.society_id
        AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
    )
  );

-- Members can INSERT their own application
CREATE POLICY "member_apply_membership" ON memberships FOR INSERT
  WITH CHECK (
    profile_id = auth.uid()
    AND society_id IN (SELECT p.society_id FROM profiles p WHERE p.id = auth.uid())
  );

-- ── Staff KYC enhancements ────────────────────────────────────────────────────
-- Byelaw 13.3: security pass requires Aadhaar + 2 photos + police verification
-- Byelaw 6.16: owner responsible for character verification of domestic staff

ALTER TABLE staff_members
  ADD COLUMN IF NOT EXISTS photo_key               text,           -- Supabase Storage: member-documents bucket
  ADD COLUMN IF NOT EXISTS id_doc_key              text,           -- Supabase Storage: member-documents bucket
  ADD COLUMN IF NOT EXISTS aadhaar_last4           char(4),        -- personal data: last 4 digits only
  ADD COLUMN IF NOT EXISTS police_verified         boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS police_verification_date date,
  ADD COLUMN IF NOT EXISTS police_verification_ref text CHECK (length(police_verification_ref) <= 100),
  ADD COLUMN IF NOT EXISTS police_station          text CHECK (length(police_station) <= 200),
  ADD COLUMN IF NOT EXISTS two_photos_received     boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS security_pass_issued    boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS security_pass_issued_at timestamptz,
  ADD COLUMN IF NOT EXISTS security_pass_number    text CHECK (length(security_pass_number) <= 50),
  ADD COLUMN IF NOT EXISTS security_pass_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS kyc_status              text NOT NULL DEFAULT 'pending'
                              CHECK (kyc_status IN ('pending','documents_submitted','police_verified','pass_issued','pass_expired')),
  ADD COLUMN IF NOT EXISTS background_remarks      text CHECK (length(background_remarks) <= 500),
  ADD COLUMN IF NOT EXISTS verified_by             uuid REFERENCES profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN staff_members.aadhaar_last4 IS 'DPDPA personal data: last 4 digits of Aadhaar only';
COMMENT ON COLUMN staff_members.photo_key IS 'DPDPA personal data: Supabase Storage key in member-documents bucket';
COMMENT ON COLUMN staff_members.id_doc_key IS 'DPDPA personal data: Supabase Storage key in member-documents bucket';

-- ── Maid security pass tracking enhancements ─────────────────────────────────
-- Existing maids table (migration 041) already has photo_key, id_doc_key, police_verified
-- Adding security pass issuance tracking per byelaw 13.3

ALTER TABLE maids
  ADD COLUMN IF NOT EXISTS security_pass_issued    boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS security_pass_issued_at timestamptz,
  ADD COLUMN IF NOT EXISTS security_pass_number    text CHECK (length(security_pass_number) <= 50),
  ADD COLUMN IF NOT EXISTS security_pass_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS two_photos_received     boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS kyc_status              text NOT NULL DEFAULT 'pending'
                              CHECK (kyc_status IN ('pending','documents_submitted','police_verified','pass_issued','pass_expired'));

-- ── Module registrations ──────────────────────────────────────────────────────
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order)
SELECT id, 'memberships', 'Membership Registry', 'fa-id-card-alt', true, 95
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;

INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order)
SELECT id, 'staff_kyc', 'Staff & Maid KYC', 'fa-user-check', true, 96
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
