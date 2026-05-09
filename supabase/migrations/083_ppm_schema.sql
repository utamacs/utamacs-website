-- 083_ppm_schema.sql
-- PPM (Planned Preventive Maintenance) schema additions:
--   locations lookup, assets register, checklist support on templates and tasks.

BEGIN;

-- ── 1. Unique constraint on activity templates ────────────────────────────────
-- Deduplicate first in case seed was run multiple times before this migration.
DELETE FROM staff_activity_templates a
USING staff_activity_templates b
WHERE a.id > b.id
  AND a.society_id  = b.society_id
  AND a.department  = b.department
  AND a.title       = b.title;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_templates_dept_title'
  ) THEN
    ALTER TABLE staff_activity_templates
      ADD CONSTRAINT uq_templates_dept_title UNIQUE (society_id, department, title);
  END IF;
END $$;

-- ── 2. Locations lookup table ─────────────────────────────────────────────────
-- Stores named zones / areas within a society (blocks, utility rooms, amenities).
-- Templates reference locations via the location_variants UUID[] soft-array.

CREATE TABLE IF NOT EXISTS locations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name        varchar(100) NOT NULL,
  name_hi     varchar(100),
  name_te     varchar(100),
  -- block | common_area | utility | amenity | external
  zone_type   text NOT NULL DEFAULT 'common_area'
    CHECK (zone_type IN ('block','common_area','utility','amenity','external')),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, name)
);

CREATE INDEX IF NOT EXISTS idx_locations_society ON locations(society_id, zone_type);

ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "locations_read" ON locations;
CREATE POLICY "locations_read" ON locations FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "locations_manage" ON locations;
CREATE POLICY "locations_manage" ON locations FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── 3. Assets register ────────────────────────────────────────────────────────
-- Equipment inventory: transformers, pumps, DG sets, panels, etc.
-- Templates reference assets via asset_id FK for compliance and PPM tracking.

CREATE TABLE IF NOT EXISTS assets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name            varchar(200) NOT NULL,                -- 'Transformer-1 (800 KVA)'
  asset_code      varchar(50),                          -- 'TRANS-001'
  -- electrical | plumbing | fire_safety | hvac | civil | security | it | general
  category        text NOT NULL DEFAULT 'general'
    CHECK (category IN ('electrical','plumbing','fire_safety','hvac','civil','security','it','general')),
  make            varchar(100),                         -- 'KIRLOSKAR'
  model           varchar(100),
  serial_number   varchar(100),
  install_date    date,
  warranty_expiry date,
  location_id     uuid REFERENCES locations(id) ON DELETE SET NULL,
  location_notes  varchar(200),                         -- 'HT Yard, next to LT panel'
  -- active | under_maintenance | decommissioned
  status          text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','under_maintenance','decommissioned')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_assets_society  ON assets(society_id, category, status);
CREATE INDEX IF NOT EXISTS idx_assets_warranty ON assets(warranty_expiry) WHERE status = 'active';

ALTER TABLE assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "assets_read" ON assets;
CREATE POLICY "assets_read" ON assets FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "assets_manage" ON assets;
CREATE POLICY "assets_manage" ON assets FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── 4. Extend staff_activity_templates ───────────────────────────────────────

ALTER TABLE staff_activity_templates
  ADD COLUMN IF NOT EXISTS frequency_days        int     CHECK (frequency_days > 0),
  ADD COLUMN IF NOT EXISTS location_variants     uuid[],
  ADD COLUMN IF NOT EXISTS preferred_day_of_week smallint CHECK (preferred_day_of_week BETWEEN 0 AND 6),
  ADD COLUMN IF NOT EXISTS default_assigned_to   uuid    REFERENCES staff_members(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS asset_id              uuid    REFERENCES assets(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS checklist             jsonb   NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_templates_loc_variants ON staff_activity_templates
  USING GIN (location_variants) WHERE location_variants IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_templates_checklist ON staff_activity_templates
  USING GIN (checklist) WHERE checklist <> '[]'::jsonb;

-- ── 5. Extend staff_task_assignments ─────────────────────────────────────────

ALTER TABLE staff_task_assignments
  ADD COLUMN IF NOT EXISTS location_id         uuid  REFERENCES locations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS checklist_responses jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_tasks_location  ON staff_task_assignments(location_id) WHERE location_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_checklist ON staff_task_assignments
  USING GIN (checklist_responses) WHERE checklist_responses <> '[]'::jsonb;

COMMIT;
