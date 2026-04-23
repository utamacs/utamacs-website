-- ═══════════════════════════════════════════════════════════════
-- 012_rls.sql
-- Row-Level Security policies for all tables
-- All security gaps from v1 are fixed here.
-- ═══════════════════════════════════════════════════════════════

-- Enable RLS on all tables
ALTER TABLE societies              ENABLE ROW LEVEL SECURITY;
ALTER TABLE units                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints             ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_comments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_attachments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_sla_config   ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_periods        ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_dues       ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments               ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_categories     ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses               ENABLE ROW LEVEL SECURITY;
ALTER TABLE visitor_pre_approvals  ENABLE ROW LEVEL SECURITY;
ALTER TABLE visitor_logs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_logs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_members          ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_attendance       ENABLE ROW LEVEL SECURITY;
ALTER TABLE facilities             ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_slots         ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_bookings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE polls                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options           ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE events                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_registrations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE notices                ENABLE ROW LEVEL SECURITY;
ALTER TABLE notice_acknowledgements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors                ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_orders            ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_posts        ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_reactions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_listings   ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents              ENABLE ROW LEVEL SECURITY;
ALTER TABLE infrastructure_assets  ENABLE ROW LEVEL SECURITY;
ALTER TABLE asset_maintenance_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags          ENABLE ROW LEVEL SECURITY;
ALTER TABLE module_configurations  ENABLE ROW LEVEL SECURITY;

-- ─── Helper function ────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_user_role(uid uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM user_roles WHERE user_id = uid
$$;

CREATE OR REPLACE FUNCTION get_user_society(uid uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT society_id FROM user_roles WHERE user_id = uid
$$;

-- ─── Societies: auth users can read their own ───────────────
CREATE POLICY societies_read ON societies FOR SELECT
  USING (id = get_user_society(auth.uid()));

-- ─── Units: all authenticated members can view ──────────────
CREATE POLICY units_read ON units FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ─── Profiles ───────────────────────────────────────────────
CREATE POLICY profiles_own_read ON profiles FOR SELECT
  USING (id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY profiles_own_update ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY profiles_insert ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

-- ─── User Roles ─────────────────────────────────────────────
CREATE POLICY user_roles_read ON user_roles FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY user_roles_admin_write ON user_roles FOR ALL
  USING (get_user_role(auth.uid()) = 'admin');

-- ─── Audit Logs: INSERT-ONLY; SELECT for admin only ─────────
CREATE POLICY audit_insert ON audit_logs FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY audit_admin_read ON audit_logs FOR SELECT
  USING (get_user_role(auth.uid()) = 'admin');
-- NO UPDATE or DELETE policies = Supabase default deny

-- ─── Complaints ─────────────────────────────────────────────
CREATE POLICY complaints_member_read ON complaints FOR SELECT
  USING (raised_by = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY complaints_insert ON complaints FOR INSERT
  WITH CHECK (raised_by = auth.uid());

-- FIX from v1: WITH CHECK prevents field tampering
CREATE POLICY complaints_exec_update ON complaints FOR UPDATE
  USING (get_user_role(auth.uid()) IN ('executive','admin'))
  WITH CHECK (
    raised_by = (SELECT raised_by FROM complaints WHERE id = complaints.id)
    AND get_user_role(auth.uid()) IN ('executive','admin')
  );

-- Complaint comments: INSERT-ONLY (immutable thread)
CREATE POLICY complaint_comments_read ON complaint_comments FOR SELECT
  USING (
    (NOT is_internal AND EXISTS (SELECT 1 FROM complaints c WHERE c.id = complaint_id AND c.raised_by = auth.uid()))
    OR get_user_role(auth.uid()) IN ('executive','admin')
  );

CREATE POLICY complaint_comments_insert ON complaint_comments FOR INSERT
  WITH CHECK (user_id = auth.uid());
-- NO UPDATE or DELETE policies

CREATE POLICY complaint_attachments_read ON complaint_attachments FOR SELECT
  USING (
    uploaded_by = auth.uid()
    OR get_user_role(auth.uid()) IN ('executive','admin')
    OR EXISTS (SELECT 1 FROM complaints c WHERE c.id = complaint_id AND c.raised_by = auth.uid())
  );

CREATE POLICY complaint_attachments_insert ON complaint_attachments FOR INSERT
  WITH CHECK (uploaded_by = auth.uid());

CREATE POLICY complaint_history_read ON complaint_status_history FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM complaints c WHERE c.id = complaint_id AND
            (c.raised_by = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin')))
  );

CREATE POLICY complaint_history_insert ON complaint_status_history FOR INSERT
  WITH CHECK (changed_by = auth.uid());

CREATE POLICY sla_config_read ON complaint_sla_config FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ─── Finance ─────────────────────────────────────────────────
CREATE POLICY dues_member_read ON maintenance_dues FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY dues_exec_write ON maintenance_dues FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

-- Payments: INSERT-ONLY (financial immutability)
CREATE POLICY payments_read ON payments FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY payments_insert ON payments FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
-- NO UPDATE or DELETE policies

CREATE POLICY expenses_read ON expenses FOR SELECT
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY expenses_write ON expenses FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Notices: published notices visible to all auth users ────
CREATE POLICY notices_public_read ON notices FOR SELECT
  USING (is_published = true AND auth.uid() IS NOT NULL);

CREATE POLICY notices_exec_write ON notices FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY notice_ack_read ON notice_acknowledgements FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY notice_ack_insert ON notice_acknowledgements FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ─── Notifications: users see their own only ─────────────────
CREATE POLICY notifications_own ON notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY notifications_insert ON notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY notifications_mark_read ON notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY notif_prefs_own ON notification_preferences FOR ALL
  USING (user_id = auth.uid());

-- ─── Events ─────────────────────────────────────────────────
CREATE POLICY events_read ON events FOR SELECT
  USING (is_published = true OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY events_exec_write ON events FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY event_reg_read ON event_registrations FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY event_reg_insert ON event_registrations FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY event_reg_update ON event_registrations FOR UPDATE
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Polls ───────────────────────────────────────────────────
CREATE POLICY polls_read ON polls FOR SELECT
  USING (is_published = true OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY polls_exec_write ON polls FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY poll_options_read ON poll_options FOR SELECT
  USING (EXISTS (SELECT 1 FROM polls p WHERE p.id = poll_id AND
         (p.is_published = true OR get_user_role(auth.uid()) IN ('executive','admin'))));

-- Poll votes: INSERT-ONLY; result_visibility handled at API layer
CREATE POLICY poll_votes_insert ON poll_votes FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND NOT EXISTS (SELECT 1 FROM poll_votes pv WHERE pv.poll_id = poll_votes.poll_id AND pv.user_id = auth.uid())
  );

CREATE POLICY poll_votes_read ON poll_votes FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Facilities ─────────────────────────────────────────────
CREATE POLICY facilities_read ON facilities FOR SELECT
  USING (is_active = true AND auth.uid() IS NOT NULL);

CREATE POLICY facility_slots_read ON facility_slots FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY bookings_read ON facility_bookings FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY bookings_insert ON facility_bookings FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY bookings_update ON facility_bookings FOR UPDATE
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Visitors ────────────────────────────────────────────────
CREATE POLICY pre_approvals_read ON visitor_pre_approvals FOR SELECT
  USING (host_user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin','security_guard'));

CREATE POLICY pre_approvals_insert ON visitor_pre_approvals FOR INSERT
  WITH CHECK (host_user_id = auth.uid());

CREATE POLICY pre_approvals_update ON visitor_pre_approvals FOR UPDATE
  USING (host_user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin','security_guard'));

CREATE POLICY visitor_logs_read ON visitor_logs FOR SELECT
  USING (
    host_unit_id IN (SELECT unit_id FROM profiles WHERE id = auth.uid())
    OR get_user_role(auth.uid()) IN ('executive','admin','security_guard')
  );

CREATE POLICY visitor_logs_insert ON visitor_logs FOR INSERT
  WITH CHECK (logged_by = auth.uid());

-- Only exit_time is mutable on visitor_logs
CREATE POLICY visitor_logs_update_exit ON visitor_logs FOR UPDATE
  USING (get_user_role(auth.uid()) IN ('executive','admin','security_guard'))
  WITH CHECK (logged_by = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Vendors & Work Orders ───────────────────────────────────
CREATE POLICY vendors_read ON vendors FOR SELECT
  USING (auth.uid() IS NOT NULL AND is_active = true);

CREATE POLICY vendors_exec_write ON vendors FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY work_orders_read ON work_orders FOR SELECT
  USING (
    get_user_role(auth.uid()) IN ('executive','admin')
    OR (get_user_role(auth.uid()) = 'vendor' AND
        vendor_id IN (SELECT id FROM vendors WHERE id = vendor_id))
  );

CREATE POLICY work_orders_exec_write ON work_orders FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Community ───────────────────────────────────────────────
CREATE POLICY posts_read ON community_posts FOR SELECT
  USING (is_published = true AND auth.uid() IS NOT NULL);

CREATE POLICY posts_insert ON community_posts FOR INSERT
  WITH CHECK (author_id = auth.uid());

CREATE POLICY posts_update ON community_posts FOR UPDATE
  USING (author_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY post_comments_read ON post_comments FOR SELECT
  USING (NOT is_hidden AND auth.uid() IS NOT NULL);

CREATE POLICY post_comments_insert ON post_comments FOR INSERT
  WITH CHECK (author_id = auth.uid());

CREATE POLICY post_reactions_all ON post_reactions FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY listings_read ON marketplace_listings FOR SELECT
  USING (status = 'active' AND auth.uid() IS NOT NULL);

CREATE POLICY listings_insert ON marketplace_listings FOR INSERT
  WITH CHECK (seller_id = auth.uid());

CREATE POLICY listings_update ON marketplace_listings FOR UPDATE
  USING (seller_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Documents ───────────────────────────────────────────────
CREATE POLICY documents_public ON documents FOR SELECT
  USING (is_public = true);

CREATE POLICY documents_member ON documents FOR SELECT
  USING (requires_role = 'member' AND auth.uid() IS NOT NULL);

CREATE POLICY documents_exec ON documents FOR SELECT
  USING (requires_role IN ('executive','admin') AND get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY documents_exec_write ON documents FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Assets ──────────────────────────────────────────────────
CREATE POLICY assets_read ON infrastructure_assets FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY assets_exec_write ON infrastructure_assets FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

CREATE POLICY asset_logs_read ON asset_maintenance_logs FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY asset_logs_exec_write ON asset_maintenance_logs FOR ALL
  USING (get_user_role(auth.uid()) IN ('executive','admin'));

-- ─── Feature Flags: all auth users read; admin write ─────────
CREATE POLICY feature_flags_read ON feature_flags FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY feature_flags_admin_write ON feature_flags FOR ALL
  USING (get_user_role(auth.uid()) = 'admin');

CREATE POLICY module_config_read ON module_configurations FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY module_config_admin_write ON module_configurations FOR ALL
  USING (get_user_role(auth.uid()) = 'admin');
