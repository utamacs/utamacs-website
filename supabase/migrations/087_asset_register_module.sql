-- 087_asset_register_module.sql
-- Register 'assets' as a standalone portal module (property equipment register).
-- Note: migration 088 consolidates this into infrastructure_assets and removes this flag.

BEGIN;

INSERT INTO feature_flags (society_id, module_key, feature_key, is_enabled, allowed_roles, config_json)
SELECT
  id,
  'assets',
  'assets',
  true,
  ARRAY['executive','secretary','president'],
  '{
    "label": "Asset Register",
    "description": "Society equipment and infrastructure asset register.",
    "display_order": 26
  }'::jsonb
FROM societies
ON CONFLICT (society_id, module_key, feature_key) DO NOTHING;

COMMIT;
