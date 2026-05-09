-- 087_asset_register_module.sql
-- Register 'assets' as a standalone portal module (property equipment register).
-- Display order 26 — follows security_patrol (25).

BEGIN;

INSERT INTO feature_flags (society_id, module_key, is_active, display_order)
SELECT id, 'assets', true, 26
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;

COMMIT;
