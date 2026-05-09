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

INSERT INTO rules (society_id, rule_category, rule_code, label, description, value_type, current_value, default_value, is_locked)
SELECT id, 'staff',
  'UPLOAD_LIMIT_STAFF_PROOF_MB',
  'Staff task proof upload limit (MB)',
  'Maximum file size (MB) for task completion proof photos',
  'INTEGER', '5'::jsonb, '5'::jsonb, false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- ── Upload limit rule for compliance log documents ────────────────────────────

INSERT INTO rules (society_id, rule_category, rule_code, label, description, value_type, current_value, default_value, is_locked)
SELECT id, 'staff',
  'UPLOAD_LIMIT_STAFF_COMPLIANCE_MB',
  'Staff compliance doc upload limit (MB)',
  'Maximum file size (MB) for compliance log documents',
  'INTEGER', '10'::jsonb, '10'::jsonb, false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- ── Upload limit rule for agency contracts ────────────────────────────────────

INSERT INTO rules (society_id, rule_category, rule_code, label, description, value_type, current_value, default_value, is_locked)
SELECT id, 'staff',
  'UPLOAD_LIMIT_STAFF_CONTRACT_MB',
  'Agency contract upload limit (MB)',
  'Maximum file size (MB) for agency contract documents',
  'INTEGER', '10'::jsonb, '10'::jsonb, false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

COMMIT;
