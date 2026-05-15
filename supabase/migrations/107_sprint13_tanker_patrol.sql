-- ═══════════════════════════════════════════════════════════════
-- 107_sprint13_tanker_patrol.sql
-- Sprint 13: water tanker cost alerts + patrol attendance report
-- ═══════════════════════════════════════════════════════════════

INSERT INTO rules (society_id, rule_code, value_type, current_value, description, is_locked)
SELECT
  s.id,
  r.code,
  r.vtype,
  r.val,
  r.descr,
  false
FROM societies s
CROSS JOIN (VALUES
  ('WATER_TANKER_MAX_COST_PER_KL',      'integer', '300', 'Alert exec when a tanker delivery rate (₹ per KL) exceeds this value'),
  ('WATER_TANKER_NO_DELIVERY_ALERT_DAYS','integer', '5',   'Alert exec if no tanker delivery has been logged for this many days'),
  ('PATROL_ATTENDANCE_WINDOW_DAYS',      'integer', '30',  'Number of days to include in the guard attendance summary report')
) AS r(code, vtype, val, descr)
ON CONFLICT (society_id, rule_code) DO NOTHING;
