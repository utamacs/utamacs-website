-- Migration 034: Member & unit enhancements
-- Adds emergency contact, NRI flag, occupant count to profiles;
-- occupancy_status to units; and a tenancies table for lease tracking.

-- ─── 1. Profiles — additional resident fields ─────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS emergency_contact_name  text CHECK (length(emergency_contact_name) <= 100),
  ADD COLUMN IF NOT EXISTS emergency_contact_phone text CHECK (length(emergency_contact_phone) <= 20),  -- personal data: emergency contact
  ADD COLUMN IF NOT EXISTS emergency_contact_rel   text CHECK (emergency_contact_rel IN
    ('Spouse','Parent','Child','Sibling','Friend','Other')),
  ADD COLUMN IF NOT EXISTS num_occupants           int  NOT NULL DEFAULT 1 CHECK (num_occupants >= 0),
  ADD COLUMN IF NOT EXISTS nri_flag                boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS avatar_url              text CHECK (length(avatar_url) <= 500);
  -- avatar_url: public read URL from society-assets bucket (not signed — avatars are non-sensitive)

-- ─── 2. Units — explicit occupancy status ────────────────────────────────────

ALTER TABLE units
  ADD COLUMN IF NOT EXISTS occupancy_status text NOT NULL DEFAULT 'vacant'
    CHECK (occupancy_status IN ('owner_occupied','tenant_occupied','vacant','under_renovation'));

-- Backfill: units with a resident mapped to them are owner_occupied
UPDATE units u
SET occupancy_status = 'owner_occupied'
WHERE EXISTS (
  SELECT 1 FROM profiles p
  WHERE p.unit_id = u.id
    AND p.is_active = true
    AND p.residency_type = 'owner'
);

UPDATE units u
SET occupancy_status = 'tenant_occupied'
WHERE occupancy_status = 'vacant'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.unit_id = u.id
      AND p.is_active = true
      AND p.residency_type = 'tenant'
  );

-- ─── 3. Tenancies table — lease period tracking ───────────────────────────────

CREATE TABLE IF NOT EXISTS tenancies (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  unit_id         uuid        NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  tenant_user_id  uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lease_start     date        NOT NULL,
  lease_end       date        NOT NULL,
  lease_doc_key   text        CHECK (length(lease_doc_key) <= 500), -- personal data: rental agreement
  monthly_rent    numeric(12,2),
  is_active       boolean     NOT NULL DEFAULT true,
  created_by      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (lease_end > lease_start)
);

CREATE INDEX IF NOT EXISTS idx_tenancies_unit    ON tenancies(unit_id, is_active);
CREATE INDEX IF NOT EXISTS idx_tenancies_expiry  ON tenancies(lease_end) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_tenancies_society ON tenancies(society_id);

ALTER TABLE tenancies ENABLE ROW LEVEL SECURITY;

-- Members can view their own tenancy records; execs can view all
CREATE POLICY "member_view_own_tenancy" ON tenancies FOR SELECT
  USING (
    tenant_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
  );

CREATE POLICY "exec_manage_tenancies" ON tenancies FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
  );
