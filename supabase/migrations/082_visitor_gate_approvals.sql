-- Migration 082: Visitor Gate Approvals
-- Guards can request resident approval before letting a walk-in visitor enter.
-- Residents approve/reject from the portal; guard sees the decision in real time.

CREATE TABLE IF NOT EXISTS visitor_gate_requests (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id     uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  host_unit_id   uuid        NOT NULL REFERENCES units(id),
  visitor_name   text        NOT NULL CHECK (length(visitor_name) <= 100),
  visitor_type   text        CHECK (length(visitor_type) <= 50),
  vehicle_number text        CHECK (length(vehicle_number) <= 20),
  purpose        text        CHECK (length(purpose) <= 200),
  requested_by   uuid        NOT NULL REFERENCES profiles(id),  -- guard/exec who submitted
  status         text        NOT NULL DEFAULT 'pending'
                               CHECK (status IN ('pending','approved','rejected','expired','cancelled')),
  approved_by    uuid        REFERENCES profiles(id),           -- resident who decided
  decision_note  text        CHECK (length(decision_note) <= 300),
  created_at     timestamptz NOT NULL DEFAULT now(),
  decided_at     timestamptz,
  expires_at     timestamptz NOT NULL DEFAULT (now() + interval '10 minutes')
);

CREATE INDEX IF NOT EXISTS idx_vgr_unit_status   ON visitor_gate_requests (host_unit_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vgr_society_status ON visitor_gate_requests (society_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vgr_expires        ON visitor_gate_requests (expires_at) WHERE status = 'pending';

ALTER TABLE visitor_gate_requests ENABLE ROW LEVEL SECURITY;

-- Guards can create requests
CREATE POLICY "guard_insert_gate_requests" ON visitor_gate_requests FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'security_guard'
            AND society_id = visitor_gate_requests.society_id)
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
               AND (portal_role IN ('executive','secretary','president') OR is_admin)
               AND society_id = visitor_gate_requests.society_id)
  );

-- Residents can read requests for their own unit; guards/exec can read all
CREATE POLICY "member_read_own_unit_gate_requests" ON visitor_gate_requests FOR SELECT
  USING (
    host_unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid() AND unit_id IS NOT NULL)
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
               AND (portal_role IN ('executive','secretary','president') OR is_admin)
               AND society_id = visitor_gate_requests.society_id)
    OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'security_guard'
               AND society_id = visitor_gate_requests.society_id)
  );

-- Residents can approve/reject their unit's pending requests
CREATE POLICY "member_decide_gate_requests" ON visitor_gate_requests FOR UPDATE
  USING (
    host_unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid() AND unit_id IS NOT NULL)
    AND status = 'pending'
  )
  WITH CHECK (
    host_unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid() AND unit_id IS NOT NULL)
  );

-- Exec/admin can update any
CREATE POLICY "exec_update_gate_requests" ON visitor_gate_requests FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND (portal_role IN ('executive','secretary','president') OR is_admin))
  );

-- Guards can cancel their own pending requests
CREATE POLICY "guard_cancel_own_requests" ON visitor_gate_requests FOR UPDATE
  USING (requested_by = auth.uid() AND status = 'pending')
  WITH CHECK (status = 'cancelled');

-- Auto-expire: background job or cron will set status='expired' for stale pending rows.
-- The API also checks expires_at on read and skips expired rows.

-- Rule: approval window duration (minutes a request stays pending before auto-expiry)
INSERT INTO rules (society_id, rule_code, value_type, current_value, label, description, is_locked)
SELECT s.id, 'GATE_APPROVAL_TIMEOUT_MINS', 'int', '10',
       'Gate Approval Timeout (minutes)',
       'How long a guard-submitted gate approval request stays valid before it expires.',
       false
FROM societies s
WHERE NOT EXISTS (
  SELECT 1 FROM rules r WHERE r.society_id = s.id AND r.rule_code = 'GATE_APPROVAL_TIMEOUT_MINS'
);
