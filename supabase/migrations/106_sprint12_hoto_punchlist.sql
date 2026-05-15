-- ═══════════════════════════════════════════════════════════════
-- 106_sprint12_hoto_punchlist.sql
-- Sprint 12: HOTO punch list PDF + CSV exports + SLA alerts
-- ═══════════════════════════════════════════════════════════════

-- ── Rules ────────────────────────────────────────────────────────────────────
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
  ('HOTO_PUNCH_LIST_ENABLED',  'boolean', 'true', 'Allow exec/admin to download the formal HOTO punch list PDF'),
  ('HOTO_SLA_ALERT_DAYS',      'integer', '14',   'Number of days before builder SLA to show an alert banner on the HOTO dashboard')
) AS r(code, vtype, val, descr)
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- ── hoto_completion_reports ───────────────────────────────────────────────────
-- Audit trail for every time a punch-list PDF is generated.
CREATE TABLE IF NOT EXISTS hoto_completion_reports (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id   uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  generated_by uuid        NOT NULL REFERENCES auth.users(id),
  -- snapshot counts at time of generation
  total_items  integer     NOT NULL DEFAULT 0,
  closed_items integer     NOT NULL DEFAULT 0,
  open_snags   integer     NOT NULL DEFAULT 0,
  -- optional: category filter applied (NULL = all)
  category_filter text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hoto_completion_reports_society
  ON hoto_completion_reports(society_id, created_at DESC);

ALTER TABLE hoto_completion_reports ENABLE ROW LEVEL SECURITY;

-- Exec/admin can read and insert; no updates or deletes (immutable audit)
CREATE POLICY "hoto_completion_reports_read" ON hoto_completion_reports
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND society_id = hoto_completion_reports.society_id
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
  );

CREATE POLICY "hoto_completion_reports_insert" ON hoto_completion_reports
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND society_id = hoto_completion_reports.society_id
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
  );
