-- ═══════════════════════════════════════════════════════════════
-- 035_complaint_subcategories_ratings.sql
-- Complaint sub-categories lookup, sub_category column on complaints,
-- post-resolution star ratings, and RLS for complaint_attachments
-- ═══════════════════════════════════════════════════════════════

-- ── Sub-categories lookup table ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS complaint_sub_categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  -- DPDPA: no personal data
  category    text NOT NULL,                       -- must match complaints.category values
  sub_category text NOT NULL,
  sort_order  int NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, category, sub_category)
);

ALTER TABLE complaint_sub_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_sub_categories" ON complaint_sub_categories FOR SELECT
  USING (society_id = (
    SELECT society_id FROM profiles WHERE id = auth.uid() LIMIT 1
  ));

CREATE POLICY "exec_manage_sub_categories" ON complaint_sub_categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = complaint_sub_categories.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Seed default sub-categories ───────────────────────────────────────────────

INSERT INTO complaint_sub_categories (society_id, category, sub_category, sort_order) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Plumbing',        'Leaking Pipe',               1),
  ('00000000-0000-0000-0000-000000000001', 'Plumbing',        'Blocked Drain',              2),
  ('00000000-0000-0000-0000-000000000001', 'Plumbing',        'No Water Supply',            3),
  ('00000000-0000-0000-0000-000000000001', 'Plumbing',        'Water Heater Issue',         4),
  ('00000000-0000-0000-0000-000000000001', 'Plumbing',        'Toilet Flush Issue',         5),
  ('00000000-0000-0000-0000-000000000001', 'Electrical',      'Power Outage',               1),
  ('00000000-0000-0000-0000-000000000001', 'Electrical',      'Short Circuit',              2),
  ('00000000-0000-0000-0000-000000000001', 'Electrical',      'Faulty Switch/Socket',       3),
  ('00000000-0000-0000-0000-000000000001', 'Electrical',      'Street Light Not Working',   4),
  ('00000000-0000-0000-0000-000000000001', 'Electrical',      'Common Area Light Out',      5),
  ('00000000-0000-0000-0000-000000000001', 'Lift',            'Lift Not Working',           1),
  ('00000000-0000-0000-0000-000000000001', 'Lift',            'Lift Door Issue',            2),
  ('00000000-0000-0000-0000-000000000001', 'Lift',            'Lift Making Noise',          3),
  ('00000000-0000-0000-0000-000000000001', 'Lift',            'Emergency Alarm Faulty',     4),
  ('00000000-0000-0000-0000-000000000001', 'Security',        'Suspicious Person',          1),
  ('00000000-0000-0000-0000-000000000001', 'Security',        'Unauthorised Vehicle',       2),
  ('00000000-0000-0000-0000-000000000001', 'Security',        'CCTV Not Working',           3),
  ('00000000-0000-0000-0000-000000000001', 'Security',        'Gate Not Closing',           4),
  ('00000000-0000-0000-0000-000000000001', 'Housekeeping',    'Corridor Not Cleaned',       1),
  ('00000000-0000-0000-0000-000000000001', 'Housekeeping',    'Garbage Not Collected',      2),
  ('00000000-0000-0000-0000-000000000001', 'Housekeeping',    'Pest in Common Area',        3),
  ('00000000-0000-0000-0000-000000000001', 'Parking',         'Illegal Parking',            1),
  ('00000000-0000-0000-0000-000000000001', 'Parking',         'Parking Area Damaged',       2),
  ('00000000-0000-0000-0000-000000000001', 'Parking',         'Blocking My Slot',           3),
  ('00000000-0000-0000-0000-000000000001', 'Water_Supply',    'Overhead Tank Low',          1),
  ('00000000-0000-0000-0000-000000000001', 'Water_Supply',    'Sump Not Filled',            2),
  ('00000000-0000-0000-0000-000000000001', 'Water_Supply',    'Water Quality Issue',        3),
  ('00000000-0000-0000-0000-000000000001', 'Maintenance',     'Wall Seepage',               1),
  ('00000000-0000-0000-0000-000000000001', 'Maintenance',     'Flooring Damaged',           2),
  ('00000000-0000-0000-0000-000000000001', 'Maintenance',     'Ceiling Crack',              3),
  ('00000000-0000-0000-0000-000000000001', 'Maintenance',     'Paint Peeling',              4),
  ('00000000-0000-0000-0000-000000000001', 'Common_Area',     'Gym Equipment Damaged',      1),
  ('00000000-0000-0000-0000-000000000001', 'Common_Area',     'Club House Issue',           2),
  ('00000000-0000-0000-0000-000000000001', 'Common_Area',     'Children Play Area Issue',   3),
  ('00000000-0000-0000-0000-000000000001', 'Common_Area',     'Swimming Pool Issue',        4),
  ('00000000-0000-0000-0000-000000000001', 'Pest_Control',    'Cockroaches',                1),
  ('00000000-0000-0000-0000-000000000001', 'Pest_Control',    'Rats/Mice',                  2),
  ('00000000-0000-0000-0000-000000000001', 'Pest_Control',    'Mosquitoes',                 3),
  ('00000000-0000-0000-0000-000000000001', 'Internet_Cable',  'No Internet',                1),
  ('00000000-0000-0000-0000-000000000001', 'Internet_Cable',  'Cable TV Not Working',       2),
  ('00000000-0000-0000-0000-000000000001', 'Internet_Cable',  'Loose Cable in Corridor',    3),
  ('00000000-0000-0000-0000-000000000001', 'Generator',       'DG Not Starting',            1),
  ('00000000-0000-0000-0000-000000000001', 'Generator',       'DG Noisy',                   2),
  ('00000000-0000-0000-0000-000000000001', 'Generator',       'DG Fuel Issue',              3),
  ('00000000-0000-0000-0000-000000000001', 'Garden',          'Dead Plants',                1),
  ('00000000-0000-0000-0000-000000000001', 'Garden',          'Overgrown Grass',            2),
  ('00000000-0000-0000-0000-000000000001', 'Garden',          'Broken Sprinkler',           3),
  ('00000000-0000-0000-0000-000000000001', 'Other',           'Noise Complaint',            1),
  ('00000000-0000-0000-0000-000000000001', 'Other',           'Neighbour Dispute',          2),
  ('00000000-0000-0000-0000-000000000001', 'Other',           'Signage/Notice Board',       3),
  ('00000000-0000-0000-0000-000000000001', 'Other',           'Other Issue',                4)
ON CONFLICT (society_id, category, sub_category) DO NOTHING;

-- ── Add sub_category column to complaints ────────────────────────────────────

ALTER TABLE complaints
  ADD COLUMN IF NOT EXISTS sub_category text;

-- ── Backfill existing complaint_attachments with society_id ──────────────────
-- (table exists from migration 002 but had no society_id)

ALTER TABLE complaint_attachments
  ADD COLUMN IF NOT EXISTS society_id uuid REFERENCES societies(id);

UPDATE complaint_attachments ca
SET society_id = c.society_id
FROM complaints c
WHERE ca.complaint_id = c.id
  AND ca.society_id IS NULL;

ALTER TABLE complaint_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_attachments" ON complaint_attachments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM complaints c
      WHERE c.id = complaint_attachments.complaint_id
        AND (
          c.raised_by = auth.uid()
          OR c.assigned_to = auth.uid()
          OR EXISTS (
            SELECT 1 FROM profiles p
            JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
            WHERE p.id = auth.uid()
              AND p.society_id = c.society_id
              AND r.role IN ('executive', 'admin')
          )
        )
    )
  );

CREATE POLICY "member_insert_attachment" ON complaint_attachments FOR INSERT
  WITH CHECK (
    uploaded_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM complaints c
      JOIN profiles p ON p.id = auth.uid() AND p.society_id = c.society_id
      WHERE c.id = complaint_attachments.complaint_id
        AND c.raised_by = auth.uid()
        AND c.status NOT IN ('Resolved', 'Closed')
    )
  );

-- ── Post-resolution star ratings ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS complaint_ratings (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  complaint_id  uuid NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  rated_by      uuid NOT NULL REFERENCES auth.users(id),
  -- DPDPA: personal opinion data — consent captured at member registration
  rating        int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  feedback      text CHECK (length(feedback) <= 500),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (complaint_id, rated_by)               -- one rating per member per complaint
);

COMMENT ON COLUMN complaint_ratings.rated_by   IS 'DPDPA personal data: complaint raiser identity';
COMMENT ON COLUMN complaint_ratings.feedback    IS 'DPDPA personal data: user opinion';

ALTER TABLE complaint_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_rating" ON complaint_ratings FOR SELECT
  USING (rated_by = auth.uid());

CREATE POLICY "exec_view_all_ratings" ON complaint_ratings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = complaint_ratings.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- Members can rate their own resolved/closed complaints once
CREATE POLICY "member_insert_rating" ON complaint_ratings FOR INSERT
  WITH CHECK (
    rated_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM complaints c
      JOIN profiles p ON p.id = auth.uid() AND p.society_id = c.society_id
      WHERE c.id = complaint_ratings.complaint_id
        AND c.raised_by = auth.uid()
        AND c.status IN ('Resolved', 'Closed')
    )
  );

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_csc_society_cat ON complaint_sub_categories(society_id, category);
CREATE INDEX IF NOT EXISTS idx_complaint_ratings_complaint ON complaint_ratings(complaint_id);
CREATE INDEX IF NOT EXISTS idx_complaint_ratings_rated_by ON complaint_ratings(rated_by);
CREATE INDEX IF NOT EXISTS idx_complaint_attachments_society ON complaint_attachments(society_id);
