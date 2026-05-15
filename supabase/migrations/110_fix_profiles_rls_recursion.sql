-- Migration 110: Fix infinite recursion in profiles RLS policy
--
-- Migration 046 added "member_read_own_profile" with:
--   USING (id = auth.uid() OR society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()))
--
-- Querying the `profiles` table inside a SELECT policy on `profiles` causes
-- PostgreSQL to recursively evaluate the same policy → infinite recursion.
--
-- Fix: drop the recursive policy and the older "profiles_own_read" (migration 012),
-- then create a single clean policy that uses get_user_society() — a SECURITY DEFINER
-- function that reads from `user_roles` (not profiles), so no recursion is possible.

DROP POLICY IF EXISTS "member_read_own_profile"  ON profiles;
DROP POLICY IF EXISTS "profiles_own_read"         ON profiles;

-- Members can read any profile that belongs to their own society.
-- get_user_society() is SECURITY DEFINER and queries user_roles only — no recursion.
CREATE POLICY "profiles_select" ON profiles FOR SELECT
  USING (society_id = get_user_society(auth.uid()));

-- Also drop and recreate the update policy for consistency (it was fine, just kept here
-- to ensure only one update policy exists after 046's additions).
DROP POLICY IF EXISTS "member_update_own_profile" ON profiles;
DROP POLICY IF EXISTS "profiles_own_update"       ON profiles;

CREATE POLICY "profiles_update" ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
