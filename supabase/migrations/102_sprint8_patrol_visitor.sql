-- ═══════════════════════════════════════════════════════════════
-- 102_sprint8_patrol_visitor.sql
-- Sprint 8: patrol incident resolution + shift schedules + recurring visitor passes
-- ═══════════════════════════════════════════════════════════════

-- ── Security Patrol: incident resolution tracking ────────────────────────────

ALTER TABLE patrol_logs
  ADD COLUMN IF NOT EXISTS resolved_at      timestamptz,
  ADD COLUMN IF NOT EXISTS resolved_by      uuid REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS resolution_note  text CHECK (length(resolution_note) <= 500);

COMMENT ON COLUMN patrol_logs.resolved_at     IS 'Timestamp when exec/admin marked this incident resolved';
COMMENT ON COLUMN patrol_logs.resolved_by     IS 'personal data: profile of exec who resolved the incident';
COMMENT ON COLUMN patrol_logs.resolution_note IS 'Description of how the incident was resolved';

CREATE INDEX IF NOT EXISTS idx_patrol_logs_unresolved
  ON patrol_logs (society_id, patrol_date DESC)
  WHERE is_incident = true AND resolved_at IS NULL;

-- ── Security Patrol: guard shift schedule ────────────────────────────────────

CREATE TABLE IF NOT EXISTS patrol_schedules (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id     uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  guard_name     text        NOT NULL CHECK (length(guard_name) <= 200),
  shift          text        NOT NULL CHECK (shift IN ('morning','afternoon','evening','night','full_day')),
  -- day_of_week: 0=Sunday … 6=Saturday (array, e.g. {1,2,3,4,5} = Mon–Fri)
  days_of_week   int[]       NOT NULL CHECK (cardinality(days_of_week) > 0),
  effective_from date        NOT NULL,
  effective_to   date,       -- NULL = indefinite
  notes          text        CHECK (length(notes) <= 300),
  created_by     uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT patrol_schedules_effective_check CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

COMMENT ON TABLE  patrol_schedules                 IS 'Recurring guard shift assignments for the society';
COMMENT ON COLUMN patrol_schedules.days_of_week    IS '0=Sunday … 6=Saturday; array of applicable weekdays';
COMMENT ON COLUMN patrol_schedules.effective_to    IS 'NULL means assignment continues indefinitely';
COMMENT ON COLUMN patrol_schedules.created_by      IS 'personal data: exec who created the schedule entry';

ALTER TABLE patrol_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_patrol_schedules" ON patrol_schedules
  FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "exec_manage_patrol_schedules" ON patrol_schedules
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE INDEX IF NOT EXISTS idx_patrol_schedules_soc
  ON patrol_schedules (society_id, effective_from);

-- ── Visitor Pre-Approvals: recurring passes ───────────────────────────────────

ALTER TABLE visitor_pre_approvals
  ADD COLUMN IF NOT EXISTS is_recurring         boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recurring_days       int[],      -- 0=Sun … 6=Sat; NULL when not recurring
  ADD COLUMN IF NOT EXISTS recurrence_end_date  date;       -- last valid date for recurring pass; NULL = use expires_at

COMMENT ON COLUMN visitor_pre_approvals.is_recurring         IS 'True for regular daily-help / recurring visitor passes';
COMMENT ON COLUMN visitor_pre_approvals.recurring_days       IS '0=Sunday … 6=Saturday; days of week pass is valid on';
COMMENT ON COLUMN visitor_pre_approvals.recurrence_end_date  IS 'personal data: end date of recurring pass window';

CREATE INDEX IF NOT EXISTS idx_vpa_recurring
  ON visitor_pre_approvals (society_id, is_recurring, recurrence_end_date)
  WHERE is_recurring = true;

-- ── Rules engine seeds ────────────────────────────────────────────────────────

INSERT INTO rules (society_id, rule_code, value_type, current_value, description, is_locked)
SELECT
  s.id,
  r.code,
  r.vtype,
  r.val::jsonb,
  r.descr,
  false
FROM societies s
CROSS JOIN (VALUES
  ('PATROL_INCIDENT_SLA_DAYS',       'integer', '3',  'Days within which a patrol incident must be resolved before it is flagged overdue'),
  ('PATROL_SUMMARY_WINDOW_DAYS',     'integer', '30', 'Rolling window (days) for the patrol exec summary stats panel'),
  ('VISITOR_RECURRING_MAX_WEEKS',    'integer', '8',  'Maximum number of weeks a recurring visitor pass can span')
) AS r(code, vtype, val, descr)
ON CONFLICT (society_id, rule_code) DO NOTHING;
