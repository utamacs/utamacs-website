-- 085_assets_extend.sql
-- Extend assets table for full asset register:
--   quantity, capacity, supplier, AMC tracking columns.
-- Update category CHECK to include 'mechanical' (for lifts, DGs, pumps).
-- Seed 8 additional locations referenced in the asset list.

BEGIN;

-- ── 1. Extend assets table ────────────────────────────────────────────────────

ALTER TABLE assets
  ADD COLUMN quantity       int  NOT NULL DEFAULT 1 CHECK (quantity > 0),
  ADD COLUMN capacity       varchar(100),          -- e.g. '1000 KVA', '1600A', '100KL'
  ADD COLUMN supplier       varchar(200),          -- who supplied the equipment
  ADD COLUMN amc_vendor     varchar(200),          -- who holds the AMC contract
  ADD COLUMN amc_start_date date,
  ADD COLUMN amc_end_date   date;                  -- AMC expiry — alert if < 90 days away

-- ── 2. Expand category enum to include 'mechanical' ──────────────────────────
-- (lifts, diesel generators, pumps — neither purely electrical nor plumbing)

ALTER TABLE assets DROP CONSTRAINT IF EXISTS assets_category_check;
ALTER TABLE assets ADD CONSTRAINT assets_category_check
  CHECK (category IN ('electrical','plumbing','fire_safety','hvac',
                      'civil','security','it','general','mechanical'));

-- ── 3. AMC expiry index for upcoming-renewal queries ─────────────────────────

CREATE INDEX idx_assets_amc_expiry ON assets(amc_end_date) WHERE amc_end_date IS NOT NULL;

-- ── 4. Additional locations required by the asset list ───────────────────────

INSERT INTO locations (society_id, name, zone_type)
SELECT s.id, l.name, l.zone_type
FROM societies s
CROSS JOIN (VALUES
  ('WTP Plant',              'utility'),    -- Water Treatment Plant (distinct from STP Plant)
  ('C-Block Cellar',         'utility'),
  ('B-Block Cellar',         'utility'),
  ('Club House Terrace',     'amenity'),
  ('PLC ELE Panel Room',     'utility'),
  ('Club House 2nd Floor',   'amenity'),
  ('Club House 3rd Floor',   'amenity'),
  ('Ground Floor (Elec)',    'utility')     -- Main electrical room / HT switchgear area
) AS l(name, zone_type)
ON CONFLICT (society_id, name) DO NOTHING;

COMMIT;
