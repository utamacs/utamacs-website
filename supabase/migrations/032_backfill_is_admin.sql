-- Migration 032: Back-fill profiles.is_admin for users tagged as admin in user_roles
-- users with user_roles.role = 'admin' should have profiles.is_admin = true.
-- profiles.is_admin was added in migration 025 with DEFAULT false; existing
-- admin users need to be back-filled so API-level requireAdmin() works correctly.

UPDATE profiles p
SET is_admin = true
FROM user_roles ur
WHERE ur.user_id = p.id
  AND ur.role = 'admin'
  AND p.is_admin = false;
