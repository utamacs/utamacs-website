-- ═══════════════════════════════════════════════════════════════
-- 018_fix_fk_for_postgrest_joins.sql
-- PostgREST resolves embedded joins using FK constraints. Several
-- tables reference auth.users(id) instead of profiles(id), so the
-- profiles(full_name) join syntax fails at query time.
-- This migration retargets those FKs to profiles(id).
-- Safe because profiles.id = auth.users.id (one-to-one via trigger).
-- ═══════════════════════════════════════════════════════════════

-- community_posts.author_id → profiles(id)
ALTER TABLE community_posts
  DROP CONSTRAINT IF EXISTS community_posts_author_id_fkey,
  ADD  CONSTRAINT community_posts_author_id_fkey
       FOREIGN KEY (author_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- post_comments.author_id → profiles(id)
ALTER TABLE post_comments
  DROP CONSTRAINT IF EXISTS post_comments_author_id_fkey,
  ADD  CONSTRAINT post_comments_author_id_fkey
       FOREIGN KEY (author_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- audit_logs.user_id → profiles(id)  (was unkeyed uuid)
ALTER TABLE audit_logs
  DROP CONSTRAINT IF EXISTS audit_logs_user_id_fkey;
ALTER TABLE audit_logs
  ADD CONSTRAINT audit_logs_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE SET NULL
      NOT VALID;                       -- skips row-level validation on existing rows
ALTER TABLE audit_logs
  VALIDATE CONSTRAINT audit_logs_user_id_fkey;
