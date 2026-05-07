-- ═══════════════════════════════════════════════════════════════
-- 051_rbac_notification_preferences_rls.sql
-- RLS for notification_preferences (each user owns their row)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_notification_prefs" ON notification_preferences
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
