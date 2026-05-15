-- ═══════════════════════════════════════════════════════════════
-- 098_onboarding_requests.sql
-- Sprint 5: self-registration flow — onboarding request queue
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS onboarding_requests (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,

  request_type        text NOT NULL
                        CHECK (request_type IN ('owner','tenant','secondary_user')),
  status              text NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','under_review','approved','rejected','expired')),

  -- Applicant details (collected before account creation)
  applicant_name      text NOT NULL CHECK (length(applicant_name) <= 100),
  applicant_email     text NOT NULL CHECK (length(applicant_email) <= 200),
  applicant_phone     text NOT NULL CHECK (length(applicant_phone) <= 20),
  unit_number         text NOT NULL CHECK (length(unit_number) <= 20),
  block               text CHECK (length(block) <= 20),

  -- Owner-specific: GitHub doc path (not Supabase Storage)
  ownership_doc_key   text,

  -- Tenant-specific
  lease_start         date,
  lease_end           date,
  lease_doc_key       text,
  owner_consent_at    timestamptz,
  owner_user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Secondary user (family member)
  primary_user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  relationship        text CHECK (relationship IN ('Spouse','Parent','Child','Sibling','Other')),
  secondary_phone     text CHECK (length(secondary_phone) <= 20),

  -- Review fields
  reviewed_by         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at         timestamptz,
  rejection_reason    text CHECK (length(rejection_reason) <= 500),
  notes               text CHECK (length(notes) <= 1000),

  -- Auto-expire unapproved requests after 30 days
  expires_at          timestamptz NOT NULL DEFAULT now() + interval '30 days',
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_onboarding_society_status
  ON onboarding_requests (society_id, status);
CREATE INDEX IF NOT EXISTS idx_onboarding_email
  ON onboarding_requests (applicant_email);

ALTER TABLE onboarding_requests ENABLE ROW LEVEL SECURITY;

-- Exec/admin can view all requests for their society
CREATE POLICY "exec_view_onboarding" ON onboarding_requests FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
        AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
    )
  );

-- Exec/admin can update (approve/reject/review) requests
CREATE POLICY "exec_update_onboarding" ON onboarding_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
        AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
    )
  );

-- Authenticated members can see their own secondary-user requests
CREATE POLICY "member_view_own_secondary" ON onboarding_requests FOR SELECT
  USING (primary_user_id = auth.uid());

-- Public unauthenticated insert (applicant submits before having an account)
CREATE POLICY "public_insert_onboarding" ON onboarding_requests FOR INSERT
  WITH CHECK (true);

-- ─── Module configuration seed ──────────────────────────────────
INSERT INTO module_configurations (society_id, module_key, display_name, display_order, is_active)
SELECT id, 'onboarding', 'Member Onboarding', 97, true
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
