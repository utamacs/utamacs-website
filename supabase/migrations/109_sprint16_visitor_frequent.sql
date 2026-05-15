-- Sprint 16: Visitor Management — frequent visitor shortcuts
-- Adds configurable rule for top-N frequent visitors display

INSERT INTO rules (society_id, rule_code, rule_category, label, value_type, current_value, default_value, description, is_locked)
SELECT
  id,
  'VISITOR_FREQUENT_TOP_N',
  'PARAMETER',
  'Frequent Visitor Shortcuts (Top N)',
  'integer',
  '10'::jsonb,
  '10'::jsonb,
  'Number of most-frequently pre-approved visitors shown as quick-pass shortcuts on the visitor form.',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;
