-- Migration 067: Feature flags for all built modules + governance_files extension
--
-- (A) Seed feature_flag rows for the 15 built modules that had none.
-- (B) Add society_id to governance_files for proper RLS and multi-tenancy.
-- (C) Add module column to governance_files for easier querying by module.
-- (D) Extend upload_queue to accept any item_type (not just HOTO items).

-- ── A. Feature flags for missing modules ──────────────────────────────────────

INSERT INTO feature_flags (society_id, module_key, feature_key, is_enabled, allowed_roles, config_json)
SELECT s.id, f.module_key, f.feature_key, f.is_enabled, f.allowed_roles::text[], f.config_json::jsonb
FROM societies s,
(VALUES
  -- AGM & Governance
  ('agm', 'agm_sessions',          true,  NULL,                          '{}'),
  ('agm', 'quorum_tracking',       true,  NULL,                          '{}'),
  ('agm', 'minutes_upload',        true,  ARRAY['executive','admin'],    '{}'),
  ('agm', 'proxy_voting',          false, NULL,                          '{"note":"Enable only after byelaw amendment"}'),

  -- Analytics & Reports
  ('analytics', 'ai_insights',     false, ARRAY['executive','admin'],    '{"note":"Requires ANTHROPIC_API_KEY"}'),
  ('analytics', 'export_pdf',      true,  ARRAY['executive','admin'],    '{}'),

  -- Documents
  ('documents', 'versioning',      true,  NULL,                          '{}'),
  ('documents', 'access_log',      true,  ARRAY['executive','admin'],    '{}'),

  -- Feedback
  ('feedback', 'anonymous',        true,  NULL,                          '{}'),
  ('feedback', 'sentiment_report', true,  ARRAY['executive','admin'],    '{}'),

  -- Gallery
  ('gallery', 'albums',            true,  NULL,                          '{}'),
  ('gallery', 'member_upload',     true,  NULL,                          '{"max_photos_per_upload":10}'),

  -- Letters
  ('letters', 'pdf_generation',    true,  ARRAY['executive','admin'],    '{}'),
  ('letters', 'github_archive',    true,  ARRAY['executive','admin'],    '{}'),
  ('letters', 'templates',         true,  ARRAY['executive','admin'],    '{}'),

  -- Maids / Domestic Help
  ('maids', 'kyc_pass',            true,  ARRAY['executive','admin'],    '{}'),
  ('maids', 'attendance',          true,  ARRAY['executive','admin'],    '{}'),
  ('maids', 'unit_approvals',      true,  NULL,                          '{}'),

  -- Parking
  ('parking', 'transfers',         true,  ARRAY['executive','admin'],    '{}'),
  ('parking', 'rc_upload',         true,  NULL,                          '{}'),
  ('parking', 'visitor_slots',     false, ARRAY['executive','admin'],    '{}'),

  -- Policies & Compliance
  ('policies', 'portal_gate',      true,  ARRAY['executive','admin'],    '{"note":"Blocks portal access until acknowledged"}'),
  ('policies', 'versioning',       true,  ARRAY['executive','admin'],    '{}'),

  -- Register (Society Membership Application)
  ('register', 'online_application', true, NULL,                         '{}'),
  ('register', 'fee_tracking',     true,  ARRAY['executive','admin'],    '{}'),
  ('register', 'share_certificate',true,  ARRAY['executive','admin'],    '{}'),

  -- Security Patrol
  ('security_patrol', 'shift_log', true,  ARRAY['security_guard','executive','admin'], '{}'),
  ('security_patrol', 'incidents', true,  ARRAY['security_guard','executive','admin'], '{}'),

  -- Snags
  ('snags', 'attachments',         true,  NULL,                          '{}'),
  ('snags', 'vendor_assignment',   true,  ARRAY['executive','admin'],    '{}'),

  -- Staff KYC (admin tool)
  ('staff_kyc', 'pass_issuance',   true,  ARRAY['executive','admin'],    '{}'),
  ('staff_kyc', 'police_verify',   true,  ARRAY['executive','admin'],    '{}'),

  -- Tenant KYC
  ('tenant_kyc', 'annual_rekyc',   true,  ARRAY['executive','admin'],    '{}'),
  ('tenant_kyc', 'police_verify',  true,  ARRAY['executive','admin'],    '{}'),

  -- Water Tankers
  ('water_tankers', 'booking',     true,  NULL,                          '{}'),
  ('water_tankers', 'vendor_track',true,  ARRAY['executive','admin'],    '{}')

) AS f(module_key, feature_key, is_enabled, allowed_roles, config_json)
ON CONFLICT (society_id, module_key, feature_key) DO NOTHING;

-- ── B. Add society_id to governance_files ─────────────────────────────────────
ALTER TABLE governance_files
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES societies(id) ON DELETE CASCADE;

-- ── C. Add module column for query convenience ─────────────────────────────────
ALTER TABLE governance_files
  ADD COLUMN IF NOT EXISTS module text;

CREATE INDEX IF NOT EXISTS idx_governance_files_society
  ON governance_files(society_id);

CREATE INDEX IF NOT EXISTS idx_governance_files_module
  ON governance_files(society_id, module);

-- ── D. Relax upload_queue item_id foreign key constraint ─────────────────────
-- upload_queue.item_id was originally text (not a FK), so no changes needed.
-- Add module column to mirror governance_files.
ALTER TABLE upload_queue
  ADD COLUMN IF NOT EXISTS module text;

-- ── E. RLS for governance_files ───────────────────────────────────────────────
ALTER TABLE governance_files ENABLE ROW LEVEL SECURITY;

-- Exec/admin can read all governance files for their society
CREATE POLICY IF NOT EXISTS "exec_read_governance_files" ON governance_files
  FOR SELECT USING (
    society_id IN (
      SELECT society_id FROM profiles
      WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
  );

-- Members can read non-confidential files for their society
CREATE POLICY IF NOT EXISTS "member_read_governance_files" ON governance_files
  FOR SELECT USING (
    is_confidential = false
    AND society_id IN (
      SELECT society_id FROM profiles WHERE id = auth.uid()
    )
  );

-- Inserts go through service role (API routes) only
