-- ═══════════════════════════════════════════════════════════════
-- 103_sprint9_finance_deepdive.sql
-- Sprint 9: dues reminder tracking, bulk reconciliation log
-- ═══════════════════════════════════════════════════════════════

-- ── Maintenance Dues: reminder tracking ──────────────────────────────────────

ALTER TABLE maintenance_dues
  ADD COLUMN IF NOT EXISTS reminder_sent_count   int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_reminder_sent_at timestamptz;

COMMENT ON COLUMN maintenance_dues.reminder_sent_count   IS 'Number of payment reminder notifications sent for this due';
COMMENT ON COLUMN maintenance_dues.last_reminder_sent_at IS 'Timestamp of most recent reminder dispatch';

CREATE INDEX IF NOT EXISTS idx_dues_overdue_reminder
  ON maintenance_dues (society_id, due_date, status, last_reminder_sent_at)
  WHERE status IN ('pending', 'partial');

-- ── Bulk Payment Reconciliation: import batches ───────────────────────────────

CREATE TABLE IF NOT EXISTS payment_reconcile_batches (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  imported_by     uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  imported_at     timestamptz NOT NULL DEFAULT now(),
  total_rows      int         NOT NULL DEFAULT 0,
  matched_rows    int         NOT NULL DEFAULT 0,
  skipped_rows    int         NOT NULL DEFAULT 0,
  failed_rows     int         NOT NULL DEFAULT 0,
  status          text        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending','processing','completed','failed')),
  notes           text        CHECK (length(notes) <= 500)
);

COMMENT ON TABLE  payment_reconcile_batches              IS 'Header record for each bulk payment import run';
COMMENT ON COLUMN payment_reconcile_batches.imported_by IS 'personal data: exec who initiated the reconciliation import';

ALTER TABLE payment_reconcile_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exec_manage_reconcile_batches" ON payment_reconcile_batches
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE INDEX IF NOT EXISTS idx_reconcile_batches_soc
  ON payment_reconcile_batches (society_id, imported_at DESC);

-- ── Reconcile batch line items ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS payment_reconcile_rows (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        uuid        NOT NULL REFERENCES payment_reconcile_batches(id) ON DELETE CASCADE,
  society_id      uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  row_index       int         NOT NULL,
  unit_number     text,
  amount          numeric(12,2),
  payment_date    date,
  reference_no    text        CHECK (length(reference_no) <= 100),
  raw_row         jsonb,
  status          text        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending','matched','skipped','failed')),
  matched_due_id  uuid        REFERENCES maintenance_dues(id) ON DELETE SET NULL,
  matched_payment_id uuid     REFERENCES payments(id) ON DELETE SET NULL,
  error_message   text        CHECK (length(error_message) <= 500),
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  payment_reconcile_rows                IS 'Per-row outcome of a bulk reconcile import';
COMMENT ON COLUMN payment_reconcile_rows.raw_row        IS 'Original CSV/JSON row for audit trail';
COMMENT ON COLUMN payment_reconcile_rows.matched_due_id IS 'Due that this row was matched and applied to';

ALTER TABLE payment_reconcile_rows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exec_manage_reconcile_rows" ON payment_reconcile_rows
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE INDEX IF NOT EXISTS idx_reconcile_rows_batch
  ON payment_reconcile_rows (batch_id, row_index);

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
  ('DUES_REMINDER_COOLDOWN_DAYS', 'integer', '3',  'Minimum days between payment reminders to the same unit'),
  ('DUES_REMINDER_MAX_SENDS',     'integer', '3',  'Maximum number of payment reminder notifications per due period'),
  ('DUES_AGING_BUCKET_1_DAYS',    'integer', '30', 'Upper bound (days overdue) for aging bucket 1 (1–30 days)'),
  ('DUES_AGING_BUCKET_2_DAYS',    'integer', '60', 'Upper bound (days overdue) for aging bucket 2 (31–60 days)'),
  ('DUES_AGING_BUCKET_3_DAYS',    'integer', '90', 'Upper bound (days overdue) for aging bucket 3 (61–90 days)')
) AS r(code, vtype, val, descr)
ON CONFLICT (society_id, rule_code) DO NOTHING;
