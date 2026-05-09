-- 078_staff_feedback.sql
-- Resident feedback on staff (positive/negative) and internal staff appraisal notes.

BEGIN;

CREATE TABLE staff_feedback (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  staff_id        uuid NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
  submitted_by    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source          text NOT NULL DEFAULT 'resident'
    CHECK (source IN ('resident','supervisor','afm','exec')),
  sentiment       text NOT NULL
    CHECK (sentiment IN ('positive','neutral','negative')),
  category        text NOT NULL
    CHECK (category IN ('punctuality','quality','behaviour','compliance','other')),
  message         text NOT NULL CHECK (length(message) <= 2000),
  is_anonymous    boolean NOT NULL DEFAULT false,  -- hides submitted_by in display layer
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN staff_feedback.submitted_by IS 'personal data: stored for rate-limiting; hidden in display when is_anonymous=true';

CREATE INDEX idx_staff_feedback_staff   ON staff_feedback(staff_id, created_at DESC);
CREATE INDEX idx_staff_feedback_society ON staff_feedback(society_id, created_at DESC);

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE staff_feedback ENABLE ROW LEVEL SECURITY;

-- Residents can insert (their own society)
CREATE POLICY "feedback_insert" ON staff_feedback FOR INSERT
  WITH CHECK (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND submitted_by = auth.uid()
  );

-- Staff see feedback about themselves (not the submitter if anonymous)
-- Supervisors/AFM/exec see all feedback for their society
CREATE POLICY "feedback_read" ON staff_feedback FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND id = staff_id)
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
                 AND (portal_role IN ('executive','secretary','president') OR is_admin))
      OR EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm'))
    )
  );

COMMIT;
