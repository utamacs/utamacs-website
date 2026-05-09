-- 085_assets_extend.sql
-- Extend assets table for full asset register:
--   quantity, capacity, supplier, AMC tracking columns.
-- Update category CHECK to include 'mechanical' (for lifts, DGs, pumps).
-- Seed 8 additional locations referenced in the asset list.

BEGIN;

-- ── 1. Extend assets table ────────────────────────────────────────────────────

ALTER TABLE assets
  ADD COLUMN IF NOT EXISTS quantity       int  NOT NULL DEFAULT 1 CHECK (quantity > 0),
  ADD COLUMN IF NOT EXISTS capacity       varchar(100),
  ADD COLUMN IF NOT EXISTS supplier       varchar(200),
  ADD COLUMN IF NOT EXISTS amc_vendor     varchar(200),
  ADD COLUMN IF NOT EXISTS amc_start_date date,
  ADD COLUMN IF NOT EXISTS amc_end_date   date;

-- ── 2. Expand category enum to include 'mechanical' ──────────────────────────

ALTER TABLE assets DROP CONSTRAINT IF EXISTS assets_category_check;
ALTER TABLE assets ADD CONSTRAINT assets_category_check
  CHECK (category IN ('electrical','plumbing','fire_safety','hvac',
                      'civil','security','it','general','mechanical'));

-- ── 3. AMC expiry index for upcoming-renewal queries ─────────────────────────

CREATE INDEX IF NOT EXISTS idx_assets_amc_expiry ON assets(amc_end_date) WHERE amc_end_date IS NOT NULL;

-- ── 4. Additional locations required by the asset list ───────────────────────

INSERT INTO locations (society_id, name, zone_type)
SELECT s.id, l.name, l.zone_type
FROM societies s
CROSS JOIN (VALUES
  ('WTP Plant',              'utility'),
  ('C-Block Cellar',         'utility'),
  ('B-Block Cellar',         'utility'),
  ('Club House Terrace',     'amenity'),
  ('PLC ELE Panel Room',     'utility'),
  ('Club House 2nd Floor',   'amenity'),
  ('Club House 3rd Floor',   'amenity'),
  ('Ground Floor (Elec)',    'utility')
) AS l(name, zone_type)
ON CONFLICT (society_id, name) DO NOTHING;

COMMIT;
