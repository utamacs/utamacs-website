-- 074_staff_proposals.sql
-- Supervisor-proposed activity templates pending AFM approval.

BEGIN;

CREATE TABLE staff_activity_proposals (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  department      text NOT NULL
    CHECK (department IN ('security','housekeeping','gardening','maintenance','admin','multi')),
  proposed_by     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           text NOT NULL CHECK (length(title) <= 200),
  title_hi        text           CHECK (length(title_hi) <= 200),
  title_te        text           CHECK (length(title_te) <= 200),
  description     text,
  frequency       text NOT NULL
    CHECK (frequency IN ('daily','weekly','monthly','quarterly','half_yearly','yearly','on_demand')),
  requires_photo  boolean NOT NULL DEFAULT false,
  status          text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  reviewed_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at     timestamptz,
  review_notes    text,
  -- When approved, the created template ID is stored here
  template_id     uuid REFERENCES staff_activity_templates(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_proposals_society ON staff_activity_proposals(society_id, status);
CREATE INDEX idx_proposals_dept    ON staff_activity_proposals(society_id, department, status);
CREATE INDEX idx_proposals_by      ON staff_activity_proposals(proposed_by);

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE staff_activity_proposals ENABLE ROW LEVEL SECURITY;

-- Supervisors see proposals for their department; AFM/exec see all
-- NOTE: staff_members.user_id does not exist until migration 080.
-- Policies referencing it are recreated properly in 080 after ADD COLUMN.
CREATE POLICY "proposals_read" ON staff_activity_proposals FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      proposed_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
      )
      OR false  -- afm-via-user_id: recreated in 080
    )
  );

-- Supervisors and above can insert proposals
CREATE POLICY "proposals_insert" ON staff_activity_proposals FOR INSERT
  WITH CHECK (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    OR false  -- supervisor/afm-via-user_id: recreated in 080
  );

-- Only AFM/exec can update (approve/reject)
CREATE POLICY "proposals_review" ON staff_activity_proposals FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ) OR false);  -- afm-via-user_id: recreated in 080

COMMIT;
