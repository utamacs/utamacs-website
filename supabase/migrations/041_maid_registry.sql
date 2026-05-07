-- ═══════════════════════════════════════════════════════════════
-- 041_maid_registry.sql
-- Domestic Help Registry: maids, unit approvals, attendance
-- ═══════════════════════════════════════════════════════════════

-- ── Maids master table ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS maids (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,

  -- Identity (personal data per DPDPA 2023)
  full_name     text NOT NULL CHECK (length(full_name) BETWEEN 2 AND 100),
  phone         text CHECK (length(phone) <= 15),           -- personal data: contact
  id_type       text CHECK (id_type IN ('aadhaar','voter_id','passport','dl','other')),
  id_number     text CHECK (length(id_number) <= 30),       -- personal data: government ID
  photo_key     text,                                        -- Supabase Storage key in maid-documents bucket
  id_doc_key    text,                                        -- personal data: scanned ID

  -- Employment info
  agency_name   text CHECK (length(agency_name) <= 100),
  work_type     text NOT NULL DEFAULT 'cleaning'
                CHECK (work_type IN ('cleaning','cooking','babysitting','elder_care','gardening','laundry','multiple','other')),
  is_active     boolean NOT NULL DEFAULT true,

  -- Verification
  police_verified    boolean NOT NULL DEFAULT false,
  verification_date  date,
  verified_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Dates
  registered_at timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN maids.phone      IS 'DPDPA personal data: maid contact number';
COMMENT ON COLUMN maids.id_number  IS 'DPDPA personal data: government ID number';
COMMENT ON COLUMN maids.photo_key  IS 'Supabase Storage key in maid-documents bucket — personal data: photo';
COMMENT ON COLUMN maids.id_doc_key IS 'Supabase Storage key in maid-documents bucket — personal data: ID document';

ALTER TABLE maids ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_maids" ON maids FOR SELECT
  USING (society_id IN (
    SELECT society_id FROM profiles WHERE id = auth.uid()
  ));

CREATE POLICY "exec_manage_maids" ON maids FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = maids.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Unit-maid approvals ───────────────────────────────────────────────────────
-- Links which maids are approved to enter which units

CREATE TABLE IF NOT EXISTS maid_unit_approvals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  maid_id     uuid NOT NULL REFERENCES maids(id) ON DELETE CASCADE,
  unit_id     uuid NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  approved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- personal data: resident who approved
  notes       text CHECK (length(notes) <= 300),
  is_active   boolean NOT NULL DEFAULT true,
  approved_at timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (maid_id, unit_id)
);

COMMENT ON COLUMN maid_unit_approvals.approved_by IS 'DPDPA personal data: resident who approved entry';

ALTER TABLE maid_unit_approvals ENABLE ROW LEVEL SECURITY;

-- Members see approvals for their own unit
CREATE POLICY "member_view_own_approvals" ON maid_unit_approvals FOR SELECT
  USING (
    unit_id IN (
      SELECT unit_id FROM profiles WHERE id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = maid_unit_approvals.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- Members can INSERT approvals for their own unit
CREATE POLICY "member_approve_maid" ON maid_unit_approvals FOR INSERT
  WITH CHECK (
    unit_id IN (
      SELECT unit_id FROM profiles WHERE id = auth.uid()
    )
    AND approved_by = auth.uid()
  );

-- Members can update (deactivate) their own unit's approval
CREATE POLICY "member_update_own_approval" ON maid_unit_approvals FOR UPDATE
  USING (
    unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = maid_unit_approvals.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Maid attendance ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS maid_attendance (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  maid_id     uuid NOT NULL REFERENCES maids(id) ON DELETE CASCADE,
  unit_id     uuid NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  date        date NOT NULL,
  entry_time  timetz,
  exit_time   timetz,
  marked_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- personal data
  notes       text CHECK (length(notes) <= 200),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (maid_id, unit_id, date)
);

COMMENT ON COLUMN maid_attendance.marked_by IS 'DPDPA personal data: resident who logged attendance';

ALTER TABLE maid_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_attendance" ON maid_attendance FOR SELECT
  USING (
    unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = maid_attendance.society_id
        AND r.role IN ('executive', 'admin', 'security_guard')
    )
  );

CREATE POLICY "member_log_attendance" ON maid_attendance FOR INSERT
  WITH CHECK (
    unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid())
    AND marked_by = auth.uid()
  );

CREATE POLICY "member_update_attendance" ON maid_attendance FOR UPDATE
  USING (
    unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = maid_attendance.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_maids_society        ON maids(society_id, is_active);
CREATE INDEX IF NOT EXISTS idx_maid_approvals_maid  ON maid_unit_approvals(maid_id);
CREATE INDEX IF NOT EXISTS idx_maid_approvals_unit  ON maid_unit_approvals(unit_id);
CREATE INDEX IF NOT EXISTS idx_maid_attendance_date ON maid_attendance(maid_id, date);
CREATE INDEX IF NOT EXISTS idx_maid_attendance_unit ON maid_attendance(unit_id, date);

-- ── Feature flag ─────────────────────────────────────────────────────────────

INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
SELECT id, 'maids', 'Domestic Help Registry', 17, 'fa-users', true
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
