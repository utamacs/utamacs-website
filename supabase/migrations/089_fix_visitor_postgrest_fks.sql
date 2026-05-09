-- 089_fix_visitor_postgrest_fks.sql
-- PostgREST resolves embedded joins via FK constraints.
-- visitor_pre_approvals.host_user_id referenced auth.users(id) instead of profiles(id),
-- so the `profiles!host_user_id(display_name)` join on the public pass page always failed,
-- causing a Supabase error → 404 for every valid visitor pass URL.
-- This migration retargets the FK to profiles(id) (safe: profiles.id = auth.users.id).

BEGIN;

-- Retarget visitor_pre_approvals.host_user_id → profiles(id)
ALTER TABLE visitor_pre_approvals
  DROP CONSTRAINT IF EXISTS visitor_pre_approvals_host_user_id_fkey;

ALTER TABLE visitor_pre_approvals
  ADD CONSTRAINT visitor_pre_approvals_host_user_id_fkey
      FOREIGN KEY (host_user_id) REFERENCES profiles(id) ON DELETE CASCADE
      NOT VALID;

ALTER TABLE visitor_pre_approvals
  VALIDATE CONSTRAINT visitor_pre_approvals_host_user_id_fkey;

-- Retarget visitor_logs.logged_by → profiles(id) for consistent join support
ALTER TABLE visitor_logs
  DROP CONSTRAINT IF EXISTS visitor_logs_logged_by_fkey;

ALTER TABLE visitor_logs
  ADD CONSTRAINT visitor_logs_logged_by_fkey
      FOREIGN KEY (logged_by) REFERENCES profiles(id) ON DELETE CASCADE
      NOT VALID;

ALTER TABLE visitor_logs
  VALIDATE CONSTRAINT visitor_logs_logged_by_fkey;

COMMIT;
