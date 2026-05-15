-- 108_sprint14_ppm.sql
-- Planned Preventive Maintenance (PPM) scheduler.
-- Adds ppm_schedules and ppm_completions tables linked to infrastructure_assets.
-- Rules: PPM_OVERDUE_ALERT_DAYS (alert N days before next_due_date)

BEGIN;

-- ── 1. PPM schedule table ─────────────────────────────────────────────────────
-- One row per recurring maintenance task per asset.

CREATE TABLE IF NOT EXISTS ppm_schedules (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id        uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  asset_id          uuid REFERENCES infrastructure_assets(id) ON DELETE SET NULL,
  title             varchar(200) NOT NULL,
  description       text,
  -- daily | weekly | fortnightly | monthly | quarterly | half_yearly | annual
  frequency         text NOT NULL DEFAULT 'monthly'
    CHECK (frequency IN ('daily','weekly','fortnightly','monthly','quarterly','half_yearly','annual')),
  frequency_days    int NOT NULL DEFAULT 30 CHECK (frequency_days > 0),
  responsible_role  varchar(100),
  last_completed_at date,
  next_due_date     date,
  is_active         boolean NOT NULL DEFAULT true,
  notes             text,
  created_by        uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ppm_schedules_society   ON ppm_schedules(society_id, is_active);
CREATE INDEX IF NOT EXISTS idx_ppm_schedules_next_due  ON ppm_schedules(next_due_date) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ppm_schedules_asset     ON ppm_schedules(asset_id) WHERE asset_id IS NOT NULL;

ALTER TABLE ppm_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ppm_schedules_read" ON ppm_schedules FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "ppm_schedules_manage" ON ppm_schedules FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── 2. PPM completion log ─────────────────────────────────────────────────────
-- Immutable audit: every time a PPM task is marked done.

CREATE TABLE IF NOT EXISTS ppm_completions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  schedule_id     uuid NOT NULL REFERENCES ppm_schedules(id) ON DELETE CASCADE,
  completed_on    date NOT NULL,
  completed_by    varchar(200),
  notes           text,
  cost            numeric(12,2),
  next_due_date   date,
  created_by      uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ppm_completions_schedule ON ppm_completions(schedule_id, completed_on DESC);
CREATE INDEX IF NOT EXISTS idx_ppm_completions_society  ON ppm_completions(society_id, created_at DESC);

ALTER TABLE ppm_completions ENABLE ROW LEVEL SECURITY;

-- Completions are immutable: no UPDATE or DELETE
CREATE POLICY "ppm_completions_read" ON ppm_completions FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "ppm_completions_insert" ON ppm_completions FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── 3. Rules ──────────────────────────────────────────────────────────────────

INSERT INTO rules (society_id, rule_code, value_type, current_value, label, description, is_locked)
SELECT s.id, r.rule_code, r.value_type, r.current_value::jsonb, r.label, r.description, r.is_locked
FROM societies s
CROSS JOIN (VALUES
  ('PPM_OVERDUE_ALERT_DAYS', 'integer', '7',
   'PPM upcoming alert (days)', 'Show overdue alert banner N days before next_due_date', false)
) AS r(rule_code, value_type, current_value, label, description, is_locked)
ON CONFLICT (society_id, rule_code) DO NOTHING;

COMMIT;
