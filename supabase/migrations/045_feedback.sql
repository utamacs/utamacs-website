-- ═══════════════════════════════════════════════════════════════
-- 045_feedback.sql
-- Resident Feedback: submit, respond, categorise, track
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS feedbacks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,

  -- Content
  category        text NOT NULL DEFAULT 'general'
                  CHECK (category IN ('general','maintenance','safety','amenities','management','events','other')),
  subject         text NOT NULL CHECK (length(subject) BETWEEN 3 AND 200),
  body            text NOT NULL CHECK (length(body) BETWEEN 10 AND 2000),
  rating          int CHECK (rating BETWEEN 1 AND 5),   -- optional overall satisfaction score

  -- Authorship (DPDPA: anonymous option preserves rate-limit identity server-side)
  submitted_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- personal data
  unit_id         uuid REFERENCES units(id) ON DELETE SET NULL,        -- personal data
  is_anonymous    boolean NOT NULL DEFAULT false,

  -- Workflow
  status          text NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'acknowledged', 'in_progress', 'resolved', 'closed')),
  priority        text NOT NULL DEFAULT 'normal'
                  CHECK (priority IN ('low', 'normal', 'high', 'urgent')),

  -- Response
  response        text CHECK (length(response) <= 2000),
  responded_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  responded_at    timestamptz,

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN feedbacks.submitted_by IS 'DPDPA personal data: feedback author (hidden from display when is_anonymous=true)';
COMMENT ON COLUMN feedbacks.unit_id      IS 'DPDPA personal data: unit of origin';

-- Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION touch_feedback_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_feedback_updated_at
BEFORE UPDATE ON feedbacks
FOR EACH ROW EXECUTE FUNCTION touch_feedback_updated_at();

ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

-- Members see their own feedback (non-anonymous) + all anonymous responses once responded
CREATE POLICY "member_view_own_feedback" ON feedbacks FOR SELECT
  USING (
    submitted_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = feedbacks.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

CREATE POLICY "member_submit_feedback" ON feedbacks FOR INSERT
  WITH CHECK (
    submitted_by = auth.uid()
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND society_id = feedbacks.society_id)
  );

-- Members can update only their own open feedback (e.g. edit before exec sees it)
CREATE POLICY "member_update_own_feedback" ON feedbacks FOR UPDATE
  USING (
    (submitted_by = auth.uid() AND status = 'open')
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = feedbacks.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_feedbacks_society  ON feedbacks(society_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedbacks_author   ON feedbacks(submitted_by);
CREATE INDEX IF NOT EXISTS idx_feedbacks_category ON feedbacks(society_id, category, status);

-- ── Feature flag ─────────────────────────────────────────────────────────────

INSERT INTO feature_flags (society_id, module_key, is_active, display_order)
SELECT id, 'feedback', true, 19
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
