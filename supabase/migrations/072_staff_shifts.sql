-- 072_staff_shifts.sql
-- Shift templates (morning / afternoon / night) and staff shift assignments.

BEGIN;

CREATE TABLE staff_shifts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id   uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name         text NOT NULL CHECK (length(name) <= 100),
  department   text NOT NULL
    CHECK (department IN ('security','housekeeping','gardening','maintenance','admin','multi')),
  start_time   time NOT NULL,
  end_time     time NOT NULL,
  days_of_week int[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}', -- 1=Mon … 7=Sun (ISO 8601)
  grace_mins   int NOT NULL DEFAULT 10 CHECK (grace_mins >= 0),
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  created_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX idx_staff_shifts_society ON staff_shifts(society_id, department);

-- Link staff members to their current shift
ALTER TABLE staff_members
  ADD COLUMN IF NOT EXISTS shift_id uuid REFERENCES staff_shifts(id) ON DELETE SET NULL;

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE staff_shifts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shifts_read" ON staff_shifts FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "shifts_manage" ON staff_shifts FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Seed default shifts ───────────────────────────────────────────────────────

INSERT INTO staff_shifts (society_id, name, department, start_time, end_time, days_of_week, grace_mins)
SELECT
  s.id,
  sr.name,
  sr.department,
  sr.start_time::time,
  sr.end_time::time,
  sr.days_of_week,
  sr.grace_mins
FROM societies s
CROSS JOIN (VALUES
  ('Morning Security',     'security',     '06:00', '14:00', ARRAY[1,2,3,4,5,6,7], 10),
  ('Afternoon Security',   'security',     '14:00', '22:00', ARRAY[1,2,3,4,5,6,7], 10),
  ('Night Security',       'security',     '22:00', '06:00', ARRAY[1,2,3,4,5,6,7], 15),
  ('Housekeeping Morning', 'housekeeping', '07:00', '13:00', ARRAY[1,2,3,4,5,6,7], 10),
  ('Housekeeping Evening', 'housekeeping', '13:00', '19:00', ARRAY[1,2,3,4,5],      10),
  ('Gardening',            'gardening',    '06:00', '10:00', ARRAY[1,2,3,4,5,6],    15),
  ('Maintenance',          'maintenance',  '09:00', '18:00', ARRAY[1,2,3,4,5],      15)
) AS sr(name, department, start_time, end_time, days_of_week, grace_mins)
ON CONFLICT DO NOTHING;

COMMIT;
