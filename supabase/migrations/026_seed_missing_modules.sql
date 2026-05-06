-- Seed module_configurations entries that were missing from migration 011.
-- Uses ON CONFLICT so re-running is safe and won't overwrite admin customisations.

INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
VALUES
  -- Existing entries that were omitted from the original seed
  ('00000000-0000-0000-0000-000000000001', 'agm',     'AGM & Governance',  16, 'fa-landmark',           true),
  ('00000000-0000-0000-0000-000000000001', 'parking',  'Parking Management', 17, 'fa-car',               true),
  ('00000000-0000-0000-0000-000000000001', 'letters',  'Official Letters',   18, 'fa-envelope-open-text', true),
  -- HOTO Platform modules (added in migration 025)
  ('00000000-0000-0000-0000-000000000001', 'hoto',    'HOTO Tracker',       19, 'fa-tasks',              true),
  ('00000000-0000-0000-0000-000000000001', 'snags',   'Snag List',          20, 'fa-bug',                true)
ON CONFLICT (society_id, module_key) DO UPDATE
  SET is_active = true;
