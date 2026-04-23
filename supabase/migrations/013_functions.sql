-- ═══════════════════════════════════════════════════════════════
-- 013_functions.sql
-- Helper functions, audit triggers, and automation
-- ═══════════════════════════════════════════════════════════════

-- ─── Audit trigger function ─────────────────────────────────
-- Strips PII before logging to audit_logs
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_old_values jsonb;
  v_new_values jsonb;
  pii_fields text[] := ARRAY['phone_encrypted','id_proof_encrypted','bank_account_encrypted',
                              'otp_code_hash','visitor_phone_hash'];
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_old_values := to_jsonb(OLD) - pii_fields;
    v_new_values := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    v_old_values := NULL;
    v_new_values := to_jsonb(NEW) - pii_fields;
  ELSE
    v_old_values := to_jsonb(OLD) - pii_fields;
    v_new_values := to_jsonb(NEW) - pii_fields;
  END IF;

  INSERT INTO audit_logs (user_id, action, resource_type, resource_id, old_values, new_values)
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE((to_jsonb(NEW) ->> 'id'), (to_jsonb(OLD) ->> 'id')),
    v_old_values,
    v_new_values
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Attach audit triggers to financial tables (immutability enforcement)
CREATE TRIGGER audit_payments
  AFTER INSERT ON payments
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_expenses
  AFTER INSERT OR UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_user_roles
  AFTER INSERT OR UPDATE OR DELETE ON user_roles
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- ─── Status history trigger for complaints ──────────────────
CREATE OR REPLACE FUNCTION log_complaint_status_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO complaint_status_history (complaint_id, old_status, new_status, changed_by)
    VALUES (NEW.id, OLD.status, NEW.status, auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_complaint_status_change
  AFTER UPDATE OF status ON complaints
  FOR EACH ROW EXECUTE FUNCTION log_complaint_status_change();

-- ─── Handle reopen count increment ──────────────────────────
CREATE OR REPLACE FUNCTION increment_reopen_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'Reopened' AND OLD.status = 'Closed' THEN
    NEW.reopen_count := OLD.reopen_count + 1;
    NEW.sla_deadline := now() + (NEW.sla_hours || ' hours')::interval;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_complaint_reopen
  BEFORE UPDATE OF status ON complaints
  FOR EACH ROW EXECUTE FUNCTION increment_reopen_count();

-- ─── Feature flag lookup with caching hint ──────────────────
CREATE OR REPLACE FUNCTION is_feature_enabled(
  p_society_id  uuid,
  p_module_key  text,
  p_feature_key text,
  p_user_role   text DEFAULT NULL
)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (
      SELECT
        ff.is_enabled AND
        (ff.allowed_roles IS NULL OR p_user_role = ANY(ff.allowed_roles))
      FROM feature_flags ff
      WHERE ff.society_id = p_society_id
        AND ff.module_key = p_module_key
        AND ff.feature_key = p_feature_key
      LIMIT 1
    ),
    false
  )
$$;

-- ─── Get all enabled features for a user ────────────────────
CREATE OR REPLACE FUNCTION get_enabled_features(
  p_society_id uuid,
  p_user_role  text
)
RETURNS TABLE(module_key text, feature_key text, config_json jsonb)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT ff.module_key, ff.feature_key, ff.config_json
  FROM feature_flags ff
  WHERE ff.society_id = p_society_id
    AND ff.is_enabled = true
    AND (ff.allowed_roles IS NULL OR p_user_role = ANY(ff.allowed_roles))
$$;

-- ─── Get unread notification count ──────────────────────────
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id uuid)
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COUNT(*) FROM notifications
  WHERE user_id = p_user_id AND is_read = false
$$;

-- ─── Dashboard KPIs for member ──────────────────────────────
CREATE OR REPLACE FUNCTION get_member_dashboard_kpis(p_user_id uuid, p_society_id uuid)
RETURNS json LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'open_complaints',    (SELECT COUNT(*) FROM complaints WHERE raised_by = p_user_id AND status NOT IN ('Closed','Resolved')),
    'pending_dues',       (SELECT COALESCE(SUM(total_amount),0) FROM maintenance_dues WHERE user_id = p_user_id AND status IN ('pending','overdue')),
    'upcoming_events',    (SELECT COUNT(*) FROM events WHERE society_id = p_society_id AND is_published = true AND starts_at > now()),
    'active_polls',       (SELECT COUNT(*) FROM polls WHERE society_id = p_society_id AND is_published = true AND ends_at > now()),
    'unread_notices',     (SELECT COUNT(*) FROM notices WHERE society_id = p_society_id AND is_published = true
                           AND id NOT IN (SELECT notice_id FROM notice_acknowledgements WHERE user_id = p_user_id)),
    'unread_notifications', (SELECT COUNT(*) FROM notifications WHERE user_id = p_user_id AND is_read = false)
  ) INTO result;
  RETURN result;
END;
$$;

-- ─── Dashboard KPIs for executive ───────────────────────────
CREATE OR REPLACE FUNCTION get_executive_dashboard_kpis(p_society_id uuid)
RETURNS json LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'total_complaints',   (SELECT COUNT(*) FROM complaints WHERE society_id = p_society_id),
    'open_complaints',    (SELECT COUNT(*) FROM complaints WHERE society_id = p_society_id AND status NOT IN ('Closed','Resolved')),
    'sla_breached',       (SELECT COUNT(*) FROM complaints WHERE society_id = p_society_id AND sla_deadline < now() AND status NOT IN ('Closed','Resolved')),
    'pending_dues_total', (SELECT COALESCE(SUM(total_amount),0) FROM maintenance_dues WHERE society_id = p_society_id AND status IN ('pending','overdue')),
    'collection_rate',    (SELECT
                            CASE WHEN (SELECT COUNT(*) FROM maintenance_dues WHERE society_id = p_society_id) = 0 THEN 0
                            ELSE ROUND(100.0 * (SELECT COUNT(*) FROM maintenance_dues WHERE society_id = p_society_id AND status = 'paid') /
                                 (SELECT COUNT(*) FROM maintenance_dues WHERE society_id = p_society_id), 1)
                            END),
    'active_members',     (SELECT COUNT(*) FROM profiles WHERE society_id = p_society_id AND is_active = true),
    'upcoming_events',    (SELECT COUNT(*) FROM events WHERE society_id = p_society_id AND starts_at > now()),
    'pending_bookings',   (SELECT COUNT(*) FROM facility_bookings fb JOIN facilities f ON f.id = fb.facility_id WHERE f.society_id = p_society_id AND fb.status = 'pending')
  ) INTO result;
  RETURN result;
END;
$$;
