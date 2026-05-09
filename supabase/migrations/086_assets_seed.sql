-- 086_assets_seed.sql
-- Seed UTAMACS asset register from the official asset list document.
-- 70 distinct asset records covering electrical panels, DG sets, lifts,
-- pumps, tanks, HVAC, security, and civil amenities.
-- Lift serial numbers and AMC contract periods from the lift register.

BEGIN;

-- Temp table for location ID lookup by name
CREATE TEMP TABLE _aloc ON COMMIT DROP AS
  SELECT l.society_id, l.name, l.id FROM locations l;
CREATE INDEX ON _aloc(society_id, name);

INSERT INTO assets
  (society_id, name, asset_code, category, make, model, serial_number,
   capacity, location_id, location_notes, quantity, supplier,
   amc_vendor, amc_start_date, amc_end_date, status)
SELECT
  soc.id,
  a.name, a.code, a.cat, a.make, a.model, a.serial,
  a.cap,
  (SELECT id FROM _aloc WHERE society_id = soc.id AND _aloc.name = a.loc LIMIT 1),
  a.loc_notes,
  a.qty, a.supplier,
  a.amc_vendor, a.amc_start::date, a.amc_end::date,
  'active'
FROM societies soc
CROSS JOIN (VALUES

  -- ═══════════════════════════════════════════════════════════════════════════
  -- ELECTRICAL — Switchgear & Main Panels (Ground Floor / LT Room / HT Yard)
  -- ═══════════════════════════════════════════════════════════════════════════
  ('Transformer',                         'EL-001','electrical','Esennar',       NULL,             'ET2-9714',        '1000 KVA', 'HT Yard',              NULL,                             1,'Essaner',  NULL, NULL, NULL),
  ('RTCC Panel',                          'EL-002','electrical','Essaner',        NULL,             NULL,              NULL,       'LT Room',              NULL,                             1,'Essaner',  NULL, NULL, NULL),
  ('Air Circuit Breaker (ACB)',           'EL-003','electrical','Lauritz Knudsen',NULL,             'FX965177',        '1600A',    'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Vacuum Circuit Breaker 1 (VCB-1)',   'EL-004','electrical','Pentagon',       NULL,             'VB2484',          '800A',     'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Vacuum Circuit Breaker 2 (VCB-2)',   'EL-005','electrical','Pentagon',       NULL,             'VB2485',          '800A',     'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('DG Set 1',                           'ME-001','mechanical','Kirloskar',      NULL,             'DU0.9107/2420244','150 KVA',  'Ground Floor (Elec)',  NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('DG Set 2',                           'ME-002','mechanical','Ashoka Leyland', NULL,             'MAHM115610',      '500 KVA',  'Ground Floor (Elec)',  NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Main LT Panel — EB Incomer',         'EL-006','electrical','Lauritz Knudsen',NULL,             'FX966449',        '1600A',    'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Main LT Panel — DG 1',              'EL-007','electrical','Lauritz Knudsen',NULL,             'FX966320',        '800A',     'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Main LT Panel — DG 2',              'EL-008','electrical','Lauritz Knudsen',NULL,             'FX966319',        '800A',     'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Main LT Panel — Bus Coupler',        'EL-009','electrical','L&T',            NULL,             'JW917582',        '1600A',    'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Main LT Panel — C Block Out-1',      'EL-010','electrical','L&T',            NULL,             'MW933177',        '800A',     'LT Room',              'C-Block out feeder',             1,'Medha',    NULL, NULL, NULL),
  ('Main LT Panel — C Block Out-2',      'EL-011','electrical','L&T',            NULL,             'MW933183',        '800A',     'LT Room',              'C-Block out feeder',             1,'Medha',    NULL, NULL, NULL),
  ('Capacitor Panel 340 KVAR',           'EL-012','electrical','L&T',            NULL,             NULL,              '630A',     'LT Room',              NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Common Area Panel',                  'EL-013','electrical','Medha med',      NULL,             NULL,              '125A',     'Ground Floor (Elec)',  NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Main Ventilation Panel',             'EL-014','electrical','Medha med',      NULL,             NULL,              '400A',     'Ground Floor (Elec)',  NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('B-Block Main Panel',                 'EL-015','electrical','Medha med',      NULL,             NULL,              '630A',     'B-Block',              'Ground floor DB room',           1,'Medha',    NULL, NULL, NULL),
  ('A-Block Main Panel',                 'EL-016','electrical','Medha med',      NULL,             NULL,              '630A',     'A-Block',              'Ground floor DB room',           1,'Medha',    NULL, NULL, NULL),
  ('EM LTG Panel — A Block',             'EL-017','electrical',NULL,             NULL,             NULL,              '100A',     'Terrace',              'A-Block terrace',                1, NULL,       NULL, NULL, NULL),
  ('EM LTG Panel — B Block',             'EL-018','electrical',NULL,             NULL,             NULL,              '100A',     'Terrace',              'B-Block terrace',                1, NULL,       NULL, NULL, NULL),
  ('EM LTG Panel — C Block',             'EL-019','electrical',NULL,             NULL,             NULL,              '100A',     'Terrace',              'C-Block terrace',                1, NULL,       NULL, NULL, NULL),
  ('Basement Jet Air Panel',             'EL-020','electrical',NULL,             NULL,             NULL,              '250A',     'C-Block Cellar',       NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Club House Main Panel',              'EL-021','electrical','Medha med',      NULL,             NULL,              '400A',     'Clubhouse',            NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('Club House PHE Panel',               'EL-022','electrical','Medha med',      NULL,             NULL,              '160A',     'Clubhouse',            NULL,                             1,'Medha',    NULL, NULL, NULL),
  ('STP Panel',                          'EL-023','electrical',NULL,             NULL,             NULL,              '100A',     'STP Plant',            'Ground floor, A-Block area',     1, NULL,       NULL, NULL, NULL),
  ('Street Light Panel',                 'EL-024','electrical',NULL,             NULL,             NULL,              NULL,       'Ground Floor (Elec)',  'ABC and Stage panels',           4, NULL,       NULL, NULL, NULL),
  ('Pressurization Panel',               'EL-025','electrical',NULL,             NULL,             NULL,              NULL,       'Terrace',              'A, B, C blocks',                 3, NULL,       NULL, NULL, NULL),
  ('UPS (6 KVA)',                        'EL-026','electrical','ETN',            NULL,             NULL,              '6 KVA',    'PLC ELE Panel Room',   'ABC and PLC ELE panel room',     3, NULL,       NULL, NULL, NULL),
  ('UPS (1 KVA)',                        'EL-027','electrical','ETN',            NULL,             NULL,              '1 KVA',    'PLC ELE Panel Room',   NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Emergency LTG Distribution Board',  'EL-028','electrical',NULL,             NULL,             NULL,              NULL,       'Terrace',              'ABC terrace',                    3, NULL,       NULL, NULL, NULL),
  ('RPDB',                               'EL-029','electrical',NULL,             NULL,             NULL,              NULL,       NULL,                   NULL,                             1, NULL,       NULL, NULL, NULL),
  ('EM LTG (Club House)',                'EL-030','electrical',NULL,             NULL,             NULL,              NULL,       'Clubhouse',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Raising Main Tap-Up Box — C Block', 'EL-031','electrical',NULL,             NULL,             NULL,              NULL,       'C-Block',              'Ground floor, C-Block',          2, NULL,       NULL, NULL, NULL),
  ('Raising Main Tap-Up Box — A & B Block','EL-032','electrical',NULL,          NULL,             NULL,              NULL,       'A-Block',              'Ground floor, A and B Block',    2, NULL,       NULL, NULL, NULL),
  ('Floor Tap-Up Box — C Block',        'EL-033','electrical',NULL,             NULL,             NULL,              NULL,       'C-Block',              'Ground to 7th floor, 4 per floor',28,NULL,      NULL, NULL, NULL),
  ('Floor Tap-Up Box — A & B Block',    'EL-034','electrical',NULL,             NULL,             NULL,              NULL,       'A-Block',              'Ground to 7th floor, A and B blocks',42,NULL,   NULL, NULL, NULL),
  ('Grundfos Hydropneumatics System Panel','EL-035','electrical','Grundfos',    NULL,             NULL,              NULL,       'WTP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- PLUMBING — Pumps, Tanks, Water Systems
  -- ═══════════════════════════════════════════════════════════════════════════
  ('STP Sump Motor',                     'PL-001','plumbing',  NULL,             NULL,             NULL,              NULL,       'STP Plant',            NULL,                             2, NULL,       NULL, NULL, NULL),
  ('Air Blower (STP)',                   'PL-002','plumbing',  'Dynair',         NULL,             NULL,              '12500 CFM','STP Plant',            NULL,                             2, NULL,       NULL, NULL, NULL),
  ('Garden Pump',                        'PL-003','plumbing',  'Siemens',        NULL,             NULL,              '15 HP',    'Pump Room',            NULL,                             1,'VK Engineer',NULL, NULL, NULL),
  ('OZONE System',                       'PL-004','plumbing',  NULL,             NULL,             NULL,              '10 HP',    'STP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Drain Sump Pump',                    'PL-005','plumbing',  NULL,             NULL,             NULL,              '30 W',     'Pump Room',            NULL,                             1,'VK Engineer',NULL, NULL, NULL),
  ('Hydropneumatics Pump',               'PL-006','plumbing',  'Grundfos',       NULL,             NULL,              '0.5 HP',   'WTP Plant',            NULL,                             3,'VK Engineer',NULL, NULL, NULL),
  ('Air Blower Panel (WTP)',             'PL-007','plumbing',  NULL,             NULL,             NULL,              '3 HP',     'WTP Plant',            NULL,                             1,'VK Engineer',NULL, NULL, NULL),
  ('Dosing Pump',                        'PL-008','plumbing',  NULL,             NULL,             NULL,              NULL,       'WTP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Slat Mixer Motor',                   'PL-009','plumbing',  NULL,             NULL,             NULL,              NULL,       'WTP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Soften Feed Pump',                   'PL-010','plumbing',  'Grundfos',       NULL,             NULL,              '0.9 KW',   'WTP Plant',            NULL,                             2,'VK Engineer',NULL, NULL, NULL),
  ('Swimming Pool Filter Pump',          'PL-011','plumbing',  'MAX fit',        NULL,             NULL,              NULL,       'Swimming Pool',        'Club house',                     4, NULL,       NULL, NULL, NULL),
  ('Domestic Booster Pump — Club House', 'PL-012','plumbing',  'Grundfos',       NULL,             NULL,              '0.9 KW',   'Clubhouse',            NULL,                             2,'VK Engineer',NULL, NULL, NULL),
  ('Domestic Booster Pump — A Block',   'PL-013','plumbing',  'Grundfos',       NULL,             NULL,              '0.9 KW',   'Terrace',              'A-Block terrace',                2,'VK Engineer',NULL, NULL, NULL),
  ('Domestic Booster Pump — B Block',   'PL-014','plumbing',  'Grundfos',       NULL,             NULL,              '0.9 KW',   'Terrace',              'B-Block terrace',                2,'VK Engineer',NULL, NULL, NULL),
  ('Domestic Booster Pump — C Block',   'PL-015','plumbing',  'Grundfos',       NULL,             NULL,              '0.9 KW',   'Terrace',              'C-Block terrace',                2,'VK Engineer',NULL, NULL, NULL),
  ('Sump Pump (WTP Plant)',              'PL-016','plumbing',  'Kirloskar',      NULL,             NULL,              '12.5 HP',  'WTP Plant',            NULL,                             1,'Godwin',   NULL, NULL, NULL),
  ('Sump Pump (C-Block Cellar)',         'PL-017','plumbing',  'Kirloskar',      NULL,             NULL,              '12.5 HP',  'C-Block Cellar',       NULL,                             1,'Godwin',   NULL, NULL, NULL),
  ('Sump Pump (B-Block Cellar)',         'PL-018','plumbing',  'Kirloskar',      NULL,             NULL,              '12.5 HP',  'B-Block Cellar',       NULL,                             1,'Godwin',   NULL, NULL, NULL),
  ('UG Tank Fire-1',                    'PL-019','plumbing',  NULL,             NULL,             NULL,              '100 KL',   'WTP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('UG Tank Fire-2',                    'PL-020','plumbing',  NULL,             NULL,             NULL,              '100 KL',   'WTP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('UG Tank Raw Water',                 'PL-021','plumbing',  NULL,             NULL,             NULL,              '60 KL',    'WTP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('UG Tank Domestic Water',            'PL-022','plumbing',  NULL,             NULL,             NULL,              '60 KL',    'WTP Plant',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('OH Fire Tank (per block)',           'PL-023','plumbing',  NULL,             NULL,             NULL,              '25 KL',    'Terrace',              'A, B, C block terrace',          3, NULL,       NULL, NULL, NULL),
  ('OH Domestic Tank-1 (per block)',     'PL-024','plumbing',  NULL,             NULL,             NULL,              '15 KL',    'Terrace',              'A, B, C block terrace',          3, NULL,       NULL, NULL, NULL),
  ('OH Domestic Tank-2 (per block)',     'PL-025','plumbing',  NULL,             NULL,             NULL,              '15 KL',    'Terrace',              'A, B, C block terrace',          3, NULL,       NULL, NULL, NULL),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- FIRE SAFETY
  -- ═══════════════════════════════════════════════════════════════════════════
  ('Fire Hydrant Pump',                  'FS-001','fire_safety','Kirloskar',     NULL,             NULL,              '12.5 HP',  'WTP Plant',            NULL,                             1,'Godwin',   NULL, NULL, NULL),
  ('Fire Booster Pump — A Block',        'FS-002','fire_safety','Kirloskar',     NULL,             NULL,              '3 HP',     'Terrace',              'A-Block terrace',                1,'VK Engineer',NULL, NULL, NULL),
  ('Fire Booster Pump — B Block',        'FS-003','fire_safety',NULL,            NULL,             NULL,              '3 HP',     'Terrace',              'B-Block terrace',                1, NULL,       NULL, NULL, NULL),
  ('Fire Booster Pump — C Block',        'FS-004','fire_safety',NULL,            NULL,             NULL,              '3 HP',     'Terrace',              'C-Block terrace',                1, NULL,       NULL, NULL, NULL),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- HVAC — Air Conditioning
  -- ═══════════════════════════════════════════════════════════════════════════
  ('AC Unit — CCTV Room & Office',       'HV-001','hvac',      'DAIKIN',         NULL,             NULL,              '1.5 Ton',  'Ground Floor (Elec)',  'CC TV room and Office',          2, NULL,       NULL, NULL, NULL),
  ('AC Unit — Guest Room',               'HV-002','hvac',      'DAIKIN',         NULL,             NULL,              '1.5 Ton',  'Guest Room',           NULL,                             3, NULL,       NULL, NULL, NULL),
  ('AC Unit — Club House VRF',           'HV-003','hvac',      'DAIKIN',         'RXQ12ARY6',     NULL,              NULL,       'Club House Terrace',   NULL,                             3, NULL,       NULL, NULL, NULL),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- MECHANICAL — Lifts (individual records with serial numbers & AMC dates)
  -- ═══════════════════════════════════════════════════════════════════════════
  ('Lift — SERVI (C Block)',             'LF-001','mechanical', NULL,             NULL,             '11793087',        NULL,       'C-Block',              'Service lift',                   1, NULL,       'ANKURA','2024-08-31','2025-08-31'),
  ('Lift — SERVI (A Block)',             'LF-002','mechanical', NULL,             NULL,             '11793095',        NULL,       'A-Block',              'Service lift',                   1, NULL,       'ANKURA','2024-08-31','2025-08-31'),
  ('Lift — SERVI (B Block)',             'LF-003','mechanical', NULL,             NULL,             '11793101',        NULL,       'B-Block',              'Service lift',                   1, NULL,       'ANKURA','2024-08-31','2025-08-31'),
  ('Lift — L2 (C Block)',                'LF-004','mechanical', NULL,             NULL,             '11793083',        NULL,       'C-Block',              'Passenger lift L2',              1, NULL,       'ANKURA','2024-12-28','2025-12-28'),
  ('Lift — L1 (C Block)',                'LF-005','mechanical', NULL,             NULL,             '11793098',        NULL,       'C-Block',              'Passenger lift L1',              1, NULL,       'ANKURA','2024-12-28','2025-12-28'),
  ('Lift — L2 (B Block)',                'LF-006','mechanical', NULL,             NULL,             '11793092',        NULL,       'B-Block',              'Passenger lift L2',              1, NULL,       'ANKURA','2025-01-15','2026-01-15'),
  ('Lift — L1 (B Block)',                'LF-007','mechanical', NULL,             NULL,             '11793099',        NULL,       'B-Block',              'Passenger lift L1',              1, NULL,       'ANKURA','2025-01-15','2026-01-15'),
  ('Lift — L2 (A Block)',                'LF-008','mechanical', NULL,             NULL,             '11793086',        NULL,       'A-Block',              'Passenger lift L2',              1, NULL,       'ANKURA','2025-02-03','2026-02-03'),
  ('Lift — L1 (A Block)',                'LF-009','mechanical', NULL,             NULL,             '11793103',        NULL,       'A-Block',              'Passenger lift L1',              1, NULL,       'ANKURA','2025-02-03','2026-02-03'),
  ('Lift — Club House',                  'LF-010','mechanical', NULL,             NULL,             '11793090',        NULL,       'Clubhouse',            NULL,                             1, NULL,       'ANKURA','2025-03-01','2026-03-01'),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- SECURITY
  -- ═══════════════════════════════════════════════════════════════════════════
  ('CCTV MVR',                           'SC-001','security',  NULL,             NULL,             NULL,              NULL,       'Ground Floor (Elec)',  'Security control room',          2, NULL,       NULL, NULL, NULL),
  ('Boom Barrier',                       'SC-002','security',  NULL,             NULL,             NULL,              NULL,       'Entrance Gate',        NULL,                             2, NULL,       NULL, NULL, NULL),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- CIVIL — Amenities & Common Spaces
  -- ═══════════════════════════════════════════════════════════════════════════
  ('GYM',                                'CI-001','civil',     'MAX fit',        NULL,             NULL,              NULL,       'Club House 2nd Floor', NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Home Theater',                       'CI-002','civil',     NULL,             NULL,             NULL,              NULL,       'Club House 3rd Floor', NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Indoor Games Room',                  'CI-003','civil',     NULL,             NULL,             NULL,              NULL,       'Club House 3rd Floor', NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Squash & Shuttle Court',             'CI-004','civil',     NULL,             NULL,             NULL,              NULL,       'Courtyard',            NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Basketball & Cricket Play Area',     'CI-005','civil',     NULL,             NULL,             NULL,              NULL,       'Children Play Area',   NULL,                             1, NULL,       NULL, NULL, NULL),
  ('Gazebo',                             'CI-006','civil',     NULL,             NULL,             NULL,              NULL,       'Gazebo (Terrace)',     NULL,                             2, NULL,       NULL, NULL, NULL),
  ('Common Area Lighting (All Blocks)',  'EL-036','electrical', NULL,            NULL,             NULL,              NULL,       NULL,                   'All A, B, C block common lights',1, NULL,       NULL, NULL, NULL),
  ('Flat DB Box & MCBs',                 'EL-037','electrical', NULL,            NULL,             NULL,              NULL,       NULL,                   'All flats; maintained on-demand',1, NULL,       NULL, NULL, NULL)

) AS a(name, code, cat, make, model, serial, cap, loc, loc_notes, qty, supplier, amc_vendor, amc_start, amc_end)
ON CONFLICT DO NOTHING;

COMMIT;
