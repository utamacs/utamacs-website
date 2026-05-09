-- 077_staff_compliance_logs.sql
-- Legally mandated SOP logs: fire, lift, water/STP, DG set, electrical, pest control.
-- These rows are IMMUTABLE (NO UPDATE, NO DELETE) — same rule as payments/audit_logs.

BEGIN;

CREATE TABLE staff_compliance_logs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  category        text NOT NULL
    CHECK (category IN ('fire','lift','water_stp','dg_set','electrical','pest_control','security_drill','other')),
  title           text NOT NULL CHECK (length(title) <= 200),
  description     text,
  performed_by    uuid NOT NULL REFERENCES staff_members(id),
  supervised_by   uuid REFERENCES staff_members(id),
  performed_at    timestamptz NOT NULL DEFAULT now(),
  next_due_at     timestamptz,
  result          text NOT NULL DEFAULT 'ok'
    CHECK (result IN ('ok','issue_found','failed')),
  issue_notes     text,
  -- Document proof (certificate, photo, inspection report)
  doc_key         text,    -- GitHub path
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid NOT NULL REFERENCES auth.users(id)
);

COMMENT ON TABLE staff_compliance_logs IS 'Legally mandated SOP logs — immutable (no UPDATE/DELETE per CLRA 1970 / NBC requirements)';

CREATE INDEX idx_compliance_society  ON staff_compliance_logs(society_id, category, performed_at DESC);
CREATE INDEX idx_compliance_next_due ON staff_compliance_logs(next_due_at) WHERE next_due_at IS NOT NULL;

-- ── RLS — append-only, no UPDATE or DELETE ───────────────────────────────────

ALTER TABLE staff_compliance_logs ENABLE ROW LEVEL SECURITY;

-- NOTE: staff_members.user_id does not exist until migration 080.
-- Policies referencing it are recreated properly in 080 after ADD COLUMN.
CREATE POLICY "compliance_read" ON staff_compliance_logs FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
              AND (portal_role IN ('executive','secretary','president') OR is_admin))
      OR false  -- supervisor/afm-via-user_id: recreated in 080
    )
  );

CREATE POLICY "compliance_insert" ON staff_compliance_logs FOR INSERT
  WITH CHECK (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
              AND (portal_role IN ('executive','secretary','president') OR is_admin))
      OR false  -- supervisor/afm-via-user_id: recreated in 080
    )
  );

-- NO UPDATE or DELETE policies — records are immutable

COMMIT;
