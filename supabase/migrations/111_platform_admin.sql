-- Migration 111: Platform admin role for multi-society management
--
-- Adds is_platform_admin to profiles (orthogonal to society admin).
-- Platform admins can provision new societies and manage the platform
-- without being bound to a specific society.
-- NOTE: Platform admin API routes use the service client (bypasses RLS);
-- we only need the column + a helper function for edge-case RLS needs.

-- ── 1. Add column ──────────────────────────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_platform_admin boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN profiles.is_platform_admin IS
  'Platform-level admin: can provision new societies, view all society data.
   Orthogonal to is_admin (which is per-society). Set manually by the operator.';

-- ── 2. SECURITY DEFINER helper (mirrors get_user_society pattern) ──────────────

CREATE OR REPLACE FUNCTION is_platform_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_platform_admin FROM profiles WHERE id = user_id LIMIT 1),
    false
  );
$$;

GRANT EXECUTE ON FUNCTION is_platform_admin(uuid) TO authenticated;

-- ── 3. Allow platform admins to read all societies ─────────────────────────────

-- Societies table RLS (previously no RLS — adding it now)
ALTER TABLE societies ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read their own society
CREATE POLICY "society_member_read" ON societies FOR SELECT
  USING (
    id = get_user_society(auth.uid())
    OR is_platform_admin(auth.uid())
  );

-- Only platform admins can insert new societies
CREATE POLICY "platform_admin_insert_society" ON societies FOR INSERT
  WITH CHECK (is_platform_admin(auth.uid()));

-- Only platform admins can update society details
CREATE POLICY "platform_admin_update_society" ON societies FOR UPDATE
  USING (is_platform_admin(auth.uid()));
