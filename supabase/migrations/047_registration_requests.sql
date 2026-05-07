-- ═══════════════════════════════════════════════════════════════
-- 047_registration_requests.sql
-- Member self-registration: request queue + exec approval
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS registration_requests (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id        uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,

  -- Applicant identity (personal data per DPDPA 2023)
  full_name         text NOT NULL CHECK (length(full_name) BETWEEN 2 AND 100),
  email             text NOT NULL CHECK (length(email) <= 254),
  phone             text CHECK (length(phone) <= 15),             -- personal data
  unit_id           uuid REFERENCES units(id) ON DELETE SET NULL, -- requested unit
  occupancy_type    text NOT NULL DEFAULT 'owner'
                    CHECK (occupancy_type IN ('owner','tenant','co_owner','family')),

  -- Identity verification
  id_type           text CHECK (id_type IN ('aadhaar','voter_id','passport','dl','other')),
  id_number         text CHECK (length(id_number) <= 30),         -- personal data: govt ID
  id_doc_key        text,                                          -- Supabase Storage key in onboarding-docs bucket

  -- Vehicle (optional)
  vehicle_reg_no    text CHECK (length(vehicle_reg_no) <= 20),    -- personal data
  vehicle_make      text CHECK (length(vehicle_make) <= 50),

  -- Move-in date
  move_in_date      date,

  -- Workflow
  status            text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','approved','rejected','duplicate')),
  reviewed_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at       timestamptz,
  rejection_reason  text CHECK (length(rejection_reason) <= 500),

  -- On approval, link to created profile
  created_profile_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,

  created_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN registration_requests.email       IS 'DPDPA personal data: applicant email';
COMMENT ON COLUMN registration_requests.phone       IS 'DPDPA personal data: applicant phone';
COMMENT ON COLUMN registration_requests.id_number   IS 'DPDPA personal data: government ID number';
COMMENT ON COLUMN registration_requests.id_doc_key  IS 'Supabase Storage key in onboarding-docs bucket — personal data: ID document scan';
COMMENT ON COLUMN registration_requests.vehicle_reg_no IS 'DPDPA personal data: vehicle registration';

ALTER TABLE registration_requests ENABLE ROW LEVEL SECURITY;

-- Exec/admin can see and manage all requests for their society
CREATE POLICY "exec_view_requests" ON registration_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = registration_requests.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

CREATE POLICY "exec_update_requests" ON registration_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = registration_requests.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- Public INSERT (unauthenticated self-registration) — enforced by SOCIETY_ID env check in API
-- No auth.uid() check here; the API handles duplicate/spam prevention
CREATE POLICY "public_submit_request" ON registration_requests FOR INSERT
  WITH CHECK (true);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_reg_requests_society ON registration_requests(society_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reg_requests_email   ON registration_requests(email);
CREATE INDEX IF NOT EXISTS idx_reg_requests_unit    ON registration_requests(unit_id);
