-- 084_ppm_seed.sql
-- Seed data: 25 society locations + 50 HK 52-Week PPM activity templates (English).
-- Hindi / Telugu titles are left NULL — exec fills them via the template edit form.

BEGIN;

-- ── 1. Locations ──────────────────────────────────────────────────────────────

INSERT INTO locations (society_id, name, zone_type)
SELECT s.id, l.name, l.zone_type
FROM societies s
CROSS JOIN (VALUES
  ('A-Block',              'block'),
  ('B-Block',              'block'),
  ('C-Block',              'block'),
  ('Clubhouse',            'amenity'),
  ('Terrace',              'common_area'),
  ('HT Yard',              'utility'),
  ('LT Room',              'utility'),
  ('Pump Room',            'utility'),
  ('STP Plant',            'utility'),
  ('Basement (Stilt)',     'common_area'),
  ('Security Room',        'utility'),
  ('Entrance Gate',        'common_area'),
  ('Courtyard',            'common_area'),
  ('Garbage Room',         'utility'),
  ('Swimming Pool',        'amenity'),
  ('Temple',               'amenity'),
  ('Children Play Area',   'amenity'),
  ('Tot Lots',             'amenity'),
  ('Gazebo (Terrace)',     'amenity'),
  ('Gazebo (Stilt)',       'amenity'),
  ('BMS Room',             'utility'),
  ('Fire Command Room',    'utility'),
  ('Party Hall',           'amenity'),
  ('Guest Room',           'amenity'),
  ('Common Corridors',     'common_area')
) AS l(name, zone_type)
ON CONFLICT (society_id, name) DO NOTHING;

-- ── 2. HK 52-Week PPM Activity Templates ─────────────────────────────────────
-- Temp table caches location IDs per society for the ARRAY(...) sub-select below.

CREATE TEMP TABLE _loc ON COMMIT DROP AS
  SELECT l.society_id, l.name, l.id
  FROM locations l;

CREATE INDEX ON _loc(society_id, name);

INSERT INTO staff_activity_templates
  (society_id, department, title, frequency, frequency_days,
   location_variants, requires_photo, estimated_mins, is_approved, is_active)
SELECT
  soc.id,
  t.dept,
  t.title,
  t.freq,
  t.freq_days,
  CASE
    WHEN t.locs IS NULL THEN NULL::uuid[]
    ELSE ARRAY(SELECT _loc.id FROM _loc WHERE _loc.society_id = soc.id AND _loc.name = ANY(t.locs))
  END,
  t.photo,
  t.mins,
  true,
  true
FROM societies soc
CROSS JOIN (VALUES

  -- ────────────────────────────────────────────────────────────────────────────
  -- Weekly HK (37 items)
  -- ────────────────────────────────────────────────────────────────────────────
  ('housekeeping','Deep Cleaning - Facility Office',       'weekly', NULL::int, NULL::text[],                                              true, 60),
  ('housekeeping','Deep Cleaning - Security Room',         'weekly', NULL,      ARRAY['Security Room'],                                    true, 30),
  ('housekeeping','Deep Cleaning - BMS Room',              'weekly', NULL,      ARRAY['BMS Room'],                                         true, 30),
  ('housekeeping','Deep Cleaning - Clubhouse',             'weekly', NULL,      ARRAY['Clubhouse'],                                        true, 90),
  ('housekeeping','Lift Deep Cleaning',                    'weekly', NULL,      NULL,                                                      true, 45),
  ('housekeeping','Glass Surface Cleaning',                'weekly', NULL,      NULL,                                                      true, 120),
  ('housekeeping','Gate Trackers Cleaning',                'weekly', NULL,      ARRAY['Entrance Gate'],                                    false,30),
  ('housekeeping','Deep Cleaning - Party Hall',            'weekly', NULL,      ARRAY['Party Hall'],                                       true, 60),
  ('housekeeping','Parking Stilt Cleaning',                'weekly', NULL,      ARRAY['Basement (Stilt)'],                                 true, 90),
  ('housekeeping','Parking Basement Cleaning',             'weekly', NULL,      NULL,                                                      true, 90),
  ('housekeeping','Temple Cleaning',                       'weekly', NULL,      ARRAY['Temple'],                                           true, 30),
  ('housekeeping','Children Play Area Cleaning',           'weekly', NULL,      ARRAY['Children Play Area'],                               true, 45),
  ('housekeeping','Fire Command Room Cleaning',            'weekly', NULL,      ARRAY['Fire Command Room'],                                true, 30),
  ('housekeeping','Parking Lift Lobby Cleaning',           'weekly', NULL,      NULL,                                                      false,30),
  ('housekeeping','HT Yard Cleaning',                      'weekly', NULL,      ARRAY['HT Yard'],                                          false,45),
  ('housekeeping','LT Room Cleaning',                      'weekly', NULL,      ARRAY['LT Room'],                                          false,30),
  ('housekeeping','Pump Room Cleaning',                    'weekly', NULL,      ARRAY['Pump Room'],                                        false,30),
  ('housekeeping','Terrace Cleaning',                      'weekly', NULL,      ARRAY['Terrace'],                                          true, 60),
  ('housekeeping','Hydrant Doors Cleaning',                'weekly', NULL,      NULL,                                                      false,30),
  ('housekeeping','Electrical Shafts Cleaning',            'weekly', NULL,      NULL,                                                      false,45),
  ('housekeeping','Courtyard Cleaning',                    'weekly', NULL,      ARRAY['Courtyard'],                                        true, 60),
  ('housekeeping','Corridor Cobweb Removal',               'weekly', NULL,      ARRAY['Common Corridors'],                                 false,60),
  ('housekeeping','Staircase Cleaning',                    'weekly', NULL,      NULL,                                                      false,60),
  ('housekeeping','Open Balcony Cleaning',                 'weekly', NULL,      NULL,                                                      false,45),
  ('housekeeping','Tot Lots Cleaning',                     'weekly', NULL,      ARRAY['Tot Lots'],                                         false,30),
  ('housekeeping','Guest Room Cleaning',                   'weekly', NULL,      ARRAY['Guest Room'],                                       true, 45),
  ('housekeeping','Directory Boards Cleaning',             'weekly', NULL,      NULL,                                                      false,20),
  ('housekeeping','Garbage Room Cleaning',                 'weekly', NULL,      ARRAY['Garbage Room'],                                     true, 30),
  ('housekeeping','Gazebo Terrace Cleaning',               'weekly', NULL,      ARRAY['Gazebo (Terrace)'],                                 false,30),
  ('housekeeping','Gazebo Stilt Cleaning',                 'weekly', NULL,      ARRAY['Gazebo (Stilt)'],                                   false,30),
  ('housekeeping','Corridor Glass Cleaning',               'weekly', NULL,      ARRAY['Common Corridors'],                                 true, 45),
  ('housekeeping','Door Mats Cleaning',                    'weekly', NULL,      NULL,                                                      false,20),
  ('housekeeping','Floor Skirting Cleaning',               'weekly', NULL,      NULL,                                                      false,30),
  ('housekeeping','Fresh Air Grills Cleaning',             'weekly', NULL,      NULL,                                                      false,45),
  ('housekeeping','Basement Fan Rooms Cleaning',           'weekly', NULL,      NULL,                                                      false,30),
  ('housekeeping','Parking Ramps Cleaning',                'weekly', NULL,      NULL,                                                      true, 45),
  ('housekeeping','Pest Fogging / Spray',                  'weekly', NULL,      NULL,                                                      false,60),

  -- ────────────────────────────────────────────────────────────────────────────
  -- Weekly Gardening (2 items)
  -- ────────────────────────────────────────────────────────────────────────────
  ('gardening','Irrigation Drips Maintenance',             'weekly', NULL,      NULL,                                                      false,60),
  ('gardening','Leaf Trimming and Removal',                'weekly', NULL,      NULL,                                                      false,90),

  -- ────────────────────────────────────────────────────────────────────────────
  -- Monthly Twice — frequency_days=15 (5 templates; Parking Water Wash has 4 variants)
  -- ────────────────────────────────────────────────────────────────────────────
  ('housekeeping','STP Room Deep Cleaning',                'monthly',15,        ARRAY['STP Plant'],                                        true, 60),
  ('housekeeping','Parking Water Wash',                    'monthly',15,        ARRAY['A-Block','B-Block','C-Block','Clubhouse'],           true, 120),
  ('housekeeping','Rain Water Chamber Cleaning',           'monthly',15,        NULL,                                                      false,45),
  ('housekeeping','Entrance Canopy Cleaning',              'monthly',15,        ARRAY['Entrance Gate'],                                    true, 30),
  ('housekeeping','Pesticide Treatment',                   'monthly',15,        NULL,                                                      true, 90),

  -- ────────────────────────────────────────────────────────────────────────────
  -- Monthly (5 items)
  -- ────────────────────────────────────────────────────────────────────────────
  ('housekeeping','Paver Blocks Water Wash',               'monthly', NULL,     NULL,                                                      true, 90),
  ('housekeeping','Swimming Pool Cleaning',                'monthly', NULL,     ARRAY['Swimming Pool'],                                    true, 120),
  ('housekeeping','Water Tanks Cleaning',                  'monthly', NULL,     NULL,                                                      true, 90),
  ('housekeeping','Terracoat Jali Cleaning',               'monthly', NULL,     NULL,                                                      false,45),
  ('housekeeping','SS Railing Polishing',                  'monthly', NULL,     NULL,                                                      true, 90),

  -- ────────────────────────────────────────────────────────────────────────────
  -- Quarterly (1 item)
  -- ────────────────────────────────────────────────────────────────────────────
  ('housekeeping','Ground Floor Entry Cobweb Removal',     'quarterly',NULL,    ARRAY['Clubhouse'],                                        false,60)

) AS t(dept, title, freq, freq_days, locs, photo, mins)
ON CONFLICT (society_id, department, title) DO NOTHING;

COMMIT;
