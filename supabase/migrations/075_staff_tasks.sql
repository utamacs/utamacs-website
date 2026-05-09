-- 075_staff_tasks.sql
-- Task instances assigned to individual staff members, with completion tracking.

BEGIN;

CREATE TABLE staff_task_assignments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  template_id     uuid REFERENCES staff_activity_templates(id) ON DELETE SET NULL,
  assigned_to     uuid NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
  assigned_by     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           text NOT NULL CHECK (length(title) <= 200),
  title_hi        text           CHECK (length(title_hi) <= 200),
  title_te        text           CHECK (length(title_te) <= 200),
  description     text,
  due_date        date NOT NULL,
  due_time        time,
  status          text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','completed','overdue','skipped')),
  priority        text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low','normal','high','urgent')),
  requires_photo  boolean NOT NULL DEFAULT false,
  -- Completion fields
  completed_at    timestamptz,
  completed_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  completion_note text,
  proof_photo_key text,    -- GitHub path to proof photo
  -- Verification by supervisor/AFM
  verified_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  verified_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tasks_assigned_to  ON staff_task_assignments(assigned_to, due_date, status);
CREATE INDEX idx_tasks_society_date ON staff_task_assignments(society_id, due_date, status);
CREATE INDEX idx_tasks_due          ON staff_task_assignments(due_date, status) WHERE status IN ('pending','in_progress','overdue');

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE staff_task_assignments ENABLE ROW LEVEL SECURITY;

-- Staff see own tasks; supervisors see team tasks; exec/admin see all
-- NOTE: staff_members.user_id does not exist until migration 080.
-- Policies referencing it are recreated properly in 080 after ADD COLUMN.
CREATE POLICY "tasks_read" ON staff_task_assignments FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      false  -- self-via-user_id: recreated in 080
      OR assigned_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
      )
      OR false  -- supervisor/afm-via-user_id: recreated in 080
    )
  );

CREATE POLICY "tasks_insert" ON staff_task_assignments FOR INSERT
  WITH CHECK (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    OR false  -- supervisor/afm-via-user_id: recreated in 080
  );

CREATE POLICY "tasks_update" ON staff_task_assignments FOR UPDATE
  USING (
    false  -- self-via-user_id: recreated in 080
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
    OR false  -- supervisor/afm-via-user_id: recreated in 080
  );

COMMIT;
