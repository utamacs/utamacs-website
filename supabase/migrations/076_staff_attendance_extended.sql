-- 076_staff_attendance_extended.sql
-- Extend staff_attendance: check-in method, supervisor override, notes, status.

BEGIN;

ALTER TABLE staff_attendance
  ADD COLUMN IF NOT EXISTS check_in_method   text NOT NULL DEFAULT 'manual'
    CHECK (check_in_method IN ('manual','qr','whatsapp','biometric')),
  ADD COLUMN IF NOT EXISTS check_out_method  text
    CHECK (check_out_method IN ('manual','qr','whatsapp','biometric')),
  ADD COLUMN IF NOT EXISTS checked_in_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS checked_out_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status            text NOT NULL DEFAULT 'present'
    CHECK (status IN ('present','absent','half_day','leave','holiday')),
  ADD COLUMN IF NOT EXISTS overtime_mins     int DEFAULT 0 CHECK (overtime_mins >= 0),
  ADD COLUMN IF NOT EXISTS notes             text,
  -- For CLRA Form XIII muster roll export
  ADD COLUMN IF NOT EXISTS shift_id          uuid REFERENCES staff_shifts(id) ON DELETE SET NULL;

-- Backfill: set checked_in_by = logged_by for existing rows
UPDATE staff_attendance SET checked_in_by = logged_by WHERE checked_in_by IS NULL;

-- Absent days are inserted explicitly (status='absent') so reports are complete
-- Allow NULL check_in for absent/leave/holiday rows
ALTER TABLE staff_attendance DROP CONSTRAINT IF EXISTS staff_attendance_check_in_not_null;

-- ── RLS: staff portal roles can read/insert own attendance ───────────────────

-- NOTE: staff_members.user_id does not exist until migration 080.
-- Policies referencing it are recreated properly in 080 after ADD COLUMN.
DROP POLICY IF EXISTS "staff_attendance_self_read" ON staff_attendance;
CREATE POLICY "staff_attendance_self_read" ON staff_attendance FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      false  -- self-via-user_id: recreated in 080
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
                 AND (portal_role IN ('executive','secretary','president') OR is_admin))
      OR false  -- supervisor/afm-via-user_id: recreated in 080
    )
  );

DROP POLICY IF EXISTS "staff_attendance_self_checkin" ON staff_attendance;
CREATE POLICY "staff_attendance_self_checkin" ON staff_attendance FOR INSERT
  WITH CHECK (false);  -- self-via-user_id: recreated in 080

DROP POLICY IF EXISTS "staff_attendance_supervisor_update" ON staff_attendance;
CREATE POLICY "staff_attendance_supervisor_update" ON staff_attendance FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND (portal_role IN ('executive','secretary','president') OR is_admin))
    OR false  -- supervisor/afm-via-user_id: recreated in 080
  );

-- ── Rules ────────────────────────────────────────────────────────────────────

INSERT INTO rules (society_id, rule_category, rule_code, label, description, value_type, current_value, default_value, is_locked)
SELECT
  s.id, r.cat, r.code, r.lbl, r.descr, r.vtype, r.val::jsonb, r.val::jsonb, r.locked
FROM societies s
CROSS JOIN (VALUES
  ('staff', 'STAFF_CHECKIN_QR_EXPIRY_SECS',  'Check-in QR token expiry (seconds)',     'Seconds a self-generated QR token is valid for check-in', 'INTEGER', '86400', false),
  ('staff', 'STAFF_OVERTIME_THRESHOLD_MINS',  'Overtime threshold (minutes past shift)', 'Minutes beyond shift end before overtime is counted',     'INTEGER', '30',    false)
) AS r(cat, code, lbl, descr, vtype, val, locked)
ON CONFLICT (society_id, rule_code) DO NOTHING;

COMMIT;
