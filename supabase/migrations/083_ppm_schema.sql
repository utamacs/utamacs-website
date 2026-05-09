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

ALTER TABLE staff_activity_templates
  ADD CONSTRAINT uq_templates_dept_title UNIQUE (society_id, department, title);

-- ── 2. Locations lookup table ─────────────────────────────────────────────────
-- Stores named zones / areas within a society (blocks, utility rooms, amenities).
-- Templates reference locations via the location_variants UUID[] soft-array.

CREATE TABLE locations (
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

CREATE INDEX idx_locations_society ON locations(society_id, zone_type);

ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "locations_read" ON locations FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "locations_manage" ON locations FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── 3. Assets register ────────────────────────────────────────────────────────
-- Equipment inventory: transformers, pumps, DG sets, panels, etc.
-- Templates reference assets via asset_id FK for compliance and PPM tracking.

CREATE TABLE assets (
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

CREATE INDEX idx_assets_society  ON assets(society_id, category, status);
CREATE INDEX idx_assets_warranty ON assets(warranty_expiry) WHERE status = 'active';

ALTER TABLE assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "assets_read" ON assets FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "assets_manage" ON assets FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── 4. Extend staff_activity_templates ───────────────────────────────────────
--
-- frequency_days INT
--   When set, overrides the default interval implied by `frequency`.
--   Example: frequency='monthly', frequency_days=15 → "Monthly Twice" (every 15 days).
--
-- location_variants UUID[]
--   Soft-reference array to locations(id).  When populated, the task scheduler
--   fans out one task instance per location on each generation cycle.
--   No FK enforcement (Postgres arrays don't support FK); enforce in application.
--
-- preferred_day_of_week SMALLINT  0=Sunday … 6=Saturday (NULL = any day in window)
--
-- default_assigned_to UUID → staff_members(id)
--   PPM owner: tasks generated from this template default to this staff member.
--
-- asset_id UUID → assets(id)
--   Linked equipment record.
--
-- checklist JSONB  (default '[]')
--   Ordered array of inspection steps.  Schema per element:
--   {
--     "id":             "<uuid-string>",
--     "order":          <int>,
--     "text_en":        "<string>",
--     "text_hi":        "<string|null>",
--     "text_te":        "<string|null>",
--     "expected_value": "<string|null>",   -- e.g. "≥ 1 MΩ", "OK / Low / Critical"
--     "photo_required": <bool>,
--     "severity":       "warning" | "critical"
--     -- critical: step failure auto-raises a Complaint via the API
--   }

ALTER TABLE staff_activity_templates
  ADD COLUMN frequency_days        int     CHECK (frequency_days > 0),
  ADD COLUMN location_variants     uuid[],
  ADD COLUMN preferred_day_of_week smallint CHECK (preferred_day_of_week BETWEEN 0 AND 6),
  ADD COLUMN default_assigned_to   uuid    REFERENCES staff_members(id) ON DELETE SET NULL,
  ADD COLUMN asset_id              uuid    REFERENCES assets(id) ON DELETE SET NULL,
  ADD COLUMN checklist             jsonb   NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX idx_templates_loc_variants ON staff_activity_templates
  USING GIN (location_variants) WHERE location_variants IS NOT NULL;

CREATE INDEX idx_templates_checklist ON staff_activity_templates
  USING GIN (checklist) WHERE checklist <> '[]'::jsonb;

-- ── 5. Extend staff_task_assignments ─────────────────────────────────────────
--
-- location_id UUID → locations(id)
--   Which specific location this task instance covers.
--   Populated when the scheduler fans out a template with location_variants.
--
-- checklist_responses JSONB  (default '[]')
--   Per-step completion tracking, mirroring the template's checklist array.  Schema:
--   {
--     "step_id":      "<matches checklist[n].id>",
--     "actual_value": "<string|null>",
--     "status":       "pass" | "fail" | "na",
--     "photo_key":    "<github-path|null>",
--     "responded_at": "<iso-timestamp>",
--     "responded_by": "<user-uuid>"
--   }

ALTER TABLE staff_task_assignments
  ADD COLUMN location_id         uuid  REFERENCES locations(id) ON DELETE SET NULL,
  ADD COLUMN checklist_responses jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX idx_tasks_location  ON staff_task_assignments(location_id) WHERE location_id IS NOT NULL;

CREATE INDEX idx_tasks_checklist ON staff_task_assignments
  USING GIN (checklist_responses) WHERE checklist_responses <> '[]'::jsonb;

COMMIT;
