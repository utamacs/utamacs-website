-- ═══════════════════════════════════════════════════════════════
-- 105_sprint11_analytics.sql
-- Sprint 11: analytics hub — trend months config, PDF flag
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
  ('ANALYTICS_TREND_MONTHS',   'integer', '12', 'Number of months to include in collection rate and expense trend charts'),
  ('ANALYTICS_PDF_ENABLED',    'boolean', 'true', 'Allow exec/admin to download an executive summary PDF from the Analytics hub'),
  ('ANALYTICS_EXPENSE_TOP_N',  'integer', '8',  'Number of top expense categories to show in the breakdown chart (rest grouped as Other)')
) AS r(code, vtype, val, descr)
ON CONFLICT (society_id, rule_code) DO NOTHING;
