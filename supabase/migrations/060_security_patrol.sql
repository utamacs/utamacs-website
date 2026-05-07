-- Migration 060: Security Patrol Log module

CREATE TABLE IF NOT EXISTS patrol_logs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  patrol_date     date NOT NULL,
  shift           text NOT NULL CHECK (shift IN ('morning','afternoon','evening','night','full_day')),
  guard_name      text NOT NULL CHECK (length(guard_name) <= 200),
  start_time      time,
  end_time        time,
  checkpoints     text[],       -- list of checkpoint names completed
  incidents       text CHECK (length(incidents) <= 2000),
  remarks         text CHECK (length(remarks) <= 1000),
  is_incident     boolean NOT NULL DEFAULT false,
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patrol_logs_society_date
  ON patrol_logs(society_id, patrol_date DESC);

CREATE INDEX IF NOT EXISTS idx_patrol_logs_incidents
  ON patrol_logs(society_id, patrol_date DESC) WHERE is_incident;

ALTER TABLE patrol_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_patrol_logs" ON patrol_logs FOR SELECT
  USING (society_id IN (
    SELECT p.society_id FROM profiles p WHERE p.id = auth.uid()
  ));

CREATE POLICY "guard_insert_patrol" ON patrol_logs FOR INSERT
  WITH CHECK (
    society_id IN (SELECT p.society_id FROM profiles p WHERE p.id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM user_roles r
      WHERE r.user_id = auth.uid()
        AND r.role IN ('security_guard','executive','admin')
    )
  );

CREATE POLICY "exec_manage_patrol" ON patrol_logs FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid()
      AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
  ));

COMMENT ON TABLE patrol_logs IS 'Daily security patrol entries logged by guards or exec';

-- Register module
INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
SELECT id, 'security_patrol', 'Security Patrol Log', 21, 'fa-shield-alt', true
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
