-- 080_staff_portal_roles_and_permissions.sql
--
-- Three changes:
--   A. Link staff_members to auth.users so staff can have portal accounts
--   B. Seed feature_permissions for three new staff portal roles
--      (staff | supervisor | afm) — matching DEFAULT_ROLE_PERMISSIONS in permissions.ts
--   C. Seed staff.* features for existing exec / secretary / president roles
--   D. Register whatsapp_trai_dlt feature flag display metadata (already seeded in 011,
--      this just ensures it exists and is visible in the admin features panel)

BEGIN;

-- ── A. Link staff_members → auth.users ───────────────────────────────────────
-- Optional: staff who are given portal access have a user_id FK.
-- Staff without portal access have user_id = NULL.

ALTER TABLE staff_members
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_staff_members_user_id ON staff_members(user_id) WHERE user_id IS NOT NULL;

-- Staff portal accounts can read their own staff_members record via user_id
DROP POLICY IF EXISTS "staff_self_read" ON staff_members;
CREATE POLICY "staff_self_read" ON staff_members FOR SELECT
  USING (user_id = auth.uid());

-- Ensure staff profiles can be linked back to their staff record
-- (portal pages can JOIN profiles → staff_members via user_id)
COMMENT ON COLUMN staff_members.user_id IS
  'Links to auth.users when this staff member has been given portal access. NULL = no portal account yet.';

-- ── Recreate policies from 074-078 that reference user_id ─────────────────────
-- Migrations 074–078 created these policies with `false` placeholders because
-- user_id did not exist yet. Now that it does, we replace them with real logic.

-- 074: staff_activity_proposals
DROP POLICY IF EXISTS "proposals_read" ON staff_activity_proposals;
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
      OR EXISTS (
        SELECT 1 FROM staff_members
        WHERE user_id = auth.uid()
        AND portal_role = 'afm'
      )
    )
  );

DROP POLICY IF EXISTS "proposals_insert" ON staff_activity_proposals;
CREATE POLICY "proposals_insert" ON staff_activity_proposals FOR INSERT
  WITH CHECK (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM staff_members
      WHERE user_id = auth.uid()
      AND portal_role IN ('supervisor','afm')
    )
  );

DROP POLICY IF EXISTS "proposals_review" ON staff_activity_proposals;
CREATE POLICY "proposals_review" ON staff_activity_proposals FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
    OR EXISTS (
      SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role = 'afm'
    )
  );

-- 075: staff_task_assignments
DROP POLICY IF EXISTS "tasks_read" ON staff_task_assignments;
CREATE POLICY "tasks_read" ON staff_task_assignments FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND id = assigned_to)
      OR assigned_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
      )
      OR EXISTS (
        SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm')
      )
    )
  );

DROP POLICY IF EXISTS "tasks_insert" ON staff_task_assignments;
CREATE POLICY "tasks_insert" ON staff_task_assignments FOR INSERT
  WITH CHECK (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm')
    )
  );

DROP POLICY IF EXISTS "tasks_update" ON staff_task_assignments;
CREATE POLICY "tasks_update" ON staff_task_assignments FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND id = assigned_to)
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
    OR EXISTS (
      SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm')
    )
  );

-- 076: staff_attendance
DROP POLICY IF EXISTS "staff_attendance_self_read" ON staff_attendance;
CREATE POLICY "staff_attendance_self_read" ON staff_attendance FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND id = staff_id)
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
                 AND (portal_role IN ('executive','secretary','president') OR is_admin))
      OR EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm'))
    )
  );

DROP POLICY IF EXISTS "staff_attendance_self_checkin" ON staff_attendance;
CREATE POLICY "staff_attendance_self_checkin" ON staff_attendance FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND id = staff_id)
  );

DROP POLICY IF EXISTS "staff_attendance_supervisor_update" ON staff_attendance;
CREATE POLICY "staff_attendance_supervisor_update" ON staff_attendance FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND (portal_role IN ('executive','secretary','president') OR is_admin))
    OR EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm'))
  );

-- 077: staff_compliance_logs
DROP POLICY IF EXISTS "compliance_read" ON staff_compliance_logs;
CREATE POLICY "compliance_read" ON staff_compliance_logs FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
              AND (portal_role IN ('executive','secretary','president') OR is_admin))
      OR EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm'))
    )
  );

DROP POLICY IF EXISTS "compliance_insert" ON staff_compliance_logs;
CREATE POLICY "compliance_insert" ON staff_compliance_logs FOR INSERT
  WITH CHECK (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
              AND (portal_role IN ('executive','secretary','president') OR is_admin))
      OR EXISTS (SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND portal_role IN ('supervisor','afm'))
    )
  );

-- 078: staff_feedback
DROP POLICY IF EXISTS "feedback_read" ON staff_feedback;
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

-- ── B. Feature permissions — new staff portal roles ───────────────────────────
-- portal_role column is TEXT (no enum constraint) — new values 'staff','supervisor','afm' are valid.
-- These rows mirror DEFAULT_ROLE_PERMISSIONS in src/lib/permissions.ts exactly.

INSERT INTO feature_permissions (society_id, role, feature, enabled, is_locked)
SELECT
  s.id,
  r.role,
  r.feature,
  r.enabled,
  r.is_locked
FROM societies s
CROSS JOIN (VALUES
  -- ── role: staff (basic — self-service only) ──────────────────────────────
  ('staff', 'staff.view_own_profile',     true,  true ),   -- locked: must always see own profile
  ('staff', 'staff.checkin',              true,  true ),   -- locked: self check-in is a basic right
  ('staff', 'staff.view_own_tasks',       true,  true ),   -- locked: must see own tasks
  ('staff', 'staff.mark_tasks',           true,  false),

  -- ── role: supervisor (dept-level operations) ─────────────────────────────
  ('supervisor', 'staff.view_own_profile',     true,  true ),
  ('supervisor', 'staff.checkin',              true,  true ),
  ('supervisor', 'staff.view_own_tasks',       true,  true ),
  ('supervisor', 'staff.mark_tasks',           true,  false),
  ('supervisor', 'staff.view_team',            true,  false),
  ('supervisor', 'staff.mark_team_attendance', true,  false),
  ('supervisor', 'staff.assign_tasks',         true,  false),
  ('supervisor', 'staff.propose_template',     true,  false),
  ('supervisor', 'staff.view_compliance',      true,  false),
  ('supervisor', 'staff.record_compliance',    true,  false),
  ('supervisor', 'staff.view_reports',         true,  false),

  -- ── role: afm (all-department operations manager) ────────────────────────
  ('afm', 'staff.view_own_profile',     true,  true ),
  ('afm', 'staff.checkin',              true,  true ),
  ('afm', 'staff.view_own_tasks',       true,  true ),
  ('afm', 'staff.mark_tasks',           true,  false),
  ('afm', 'staff.view_team',            true,  false),
  ('afm', 'staff.mark_team_attendance', true,  false),
  ('afm', 'staff.assign_tasks',         true,  false),
  ('afm', 'staff.propose_template',     true,  false),
  ('afm', 'staff.approve_proposals',    true,  false),
  ('afm', 'staff.view_all_depts',       true,  false),
  ('afm', 'staff.view_compliance',      true,  false),
  ('afm', 'staff.record_compliance',    true,  false),
  ('afm', 'staff.view_reports',         true,  false),
  ('afm', 'staff.manage',               true,  false)

) AS r(role, feature, enabled, is_locked)
ON CONFLICT (society_id, role, feature) DO NOTHING;

-- ── C. Staff management features for exec / secretary / president ─────────────
-- Exec committee members manage staff from the portal (config layer).

INSERT INTO feature_permissions (society_id, role, feature, enabled, is_locked)
SELECT
  s.id,
  r.role,
  r.feature,
  r.enabled,
  r.is_locked
FROM societies s
CROSS JOIN (VALUES
  ('executive',  'staff.view_all_depts',      true,  false),
  ('executive',  'staff.view_reports',        true,  false),
  ('executive',  'staff.approve_proposals',   true,  false),
  ('executive',  'staff.manage',              true,  false),
  ('executive',  'staff.manage_agencies',     true,  false),
  ('executive',  'staff.configure',           true,  false),

  ('secretary',  'staff.view_all_depts',      true,  false),
  ('secretary',  'staff.view_reports',        true,  false),
  ('secretary',  'staff.approve_proposals',   true,  false),
  ('secretary',  'staff.manage',              true,  false),
  ('secretary',  'staff.manage_agencies',     true,  false),
  ('secretary',  'staff.configure',           true,  false),

  ('president',  'staff.view_all_depts',      true,  false),
  ('president',  'staff.view_reports',        true,  false),
  ('president',  'staff.approve_proposals',   true,  false),
  ('president',  'staff.manage',              true,  false),
  ('president',  'staff.manage_agencies',     true,  false),
  ('president',  'staff.configure',           true,  false)

) AS r(role, feature, enabled, is_locked)
ON CONFLICT (society_id, role, feature) DO NOTHING;

-- ── D. WhatsApp feature flag ──────────────────────────────────────────────────
-- Already seeded in migration 011 (whatsapp_trai_dlt, is_enabled = false).
-- Update config_json with richer display metadata for the admin features panel.

INSERT INTO feature_flags (society_id, module_key, feature_key, is_enabled, allowed_roles, config_json)
SELECT
  id,
  'notifications',
  'whatsapp_trai_dlt',
  false,
  NULL,
  '{
    "label": "WhatsApp Notifications",
    "description": "Send task alerts, check-in confirmations, and monthly reports via WhatsApp Business API. Requires TRAI DLT entity registration and Meta template approval before enabling.",
    "requires_env": ["WHATSAPP_ACCESS_TOKEN", "WHATSAPP_PHONE_NUMBER_ID", "WHATSAPP_WEBHOOK_VERIFY_TOKEN"],
    "setup_url": "/portal/admin/whatsapp",
    "note": "Set env vars first, then enable this flag. Staff get WhatsApp check-in confirmations and task alerts in their preferred language."
  }'::jsonb
FROM societies
ON CONFLICT (society_id, module_key, feature_key) DO UPDATE
  SET config_json = EXCLUDED.config_json;   -- refresh display metadata on re-run

-- ── E. RLS — staff portal roles can read their own feature_permissions ────────
-- The existing "feature_perms_read" policy already allows exec+ to read.
-- Add a policy so staff/supervisor/afm can read their own role's permissions.

DROP POLICY IF EXISTS "staff_role_perms_read" ON feature_permissions;
CREATE POLICY "staff_role_perms_read" ON feature_permissions
  FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    AND role = (SELECT portal_role FROM profiles WHERE id = auth.uid())
  );

COMMIT;
