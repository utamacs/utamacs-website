-- 079_staff_management_module.sql
-- Register staff_management as a portal module and add upload limit rules.

BEGIN;

-- ── Register module in feature_flags ─────────────────────────────────────────

INSERT INTO feature_flags (society_id, module_key, feature_key, is_enabled, allowed_roles, config_json)
SELECT
  id,
  'staff_management',
  'staff_management',
  true,
  ARRAY['executive','secretary','president','staff','supervisor','afm'],
  '{
    "label": "Staff Management",
    "description": "Manage society staff: attendance, tasks, compliance logs, shift scheduling, and agency contracts.",
    "display_order": 97
  }'::jsonb
FROM societies
ON CONFLICT (society_id, module_key, feature_key) DO UPDATE
  SET config_json = EXCLUDED.config_json;

-- ── Upload limit rule for staff task proof photos ─────────────────────────────

INSERT INTO rules (society_id, rule_code, description, value_type, current_value, is_locked)
SELECT id,
  'UPLOAD_LIMIT_STAFF_PROOF_MB',
  'Maximum file size (MB) for task completion proof photos',
  'integer', '5', false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- ── Upload limit rule for compliance log documents ────────────────────────────

INSERT INTO rules (society_id, rule_code, description, value_type, current_value, is_locked)
SELECT id,
  'UPLOAD_LIMIT_STAFF_COMPLIANCE_MB',
  'Maximum file size (MB) for compliance log documents',
  'integer', '10', false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- ── Upload limit rule for agency contracts ────────────────────────────────────

INSERT INTO rules (society_id, rule_code, description, value_type, current_value, is_locked)
SELECT id,
  'UPLOAD_LIMIT_STAFF_CONTRACT_MB',
  'Maximum file size (MB) for agency contract documents',
  'integer', '10', false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

COMMIT;
