-- Sprint 5: extend executive dashboard KPIs with occupancy, visitor, and onboarding counts

CREATE OR REPLACE FUNCTION get_executive_dashboard_kpis(p_society_id uuid)
RETURNS json LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'total_complaints',    (SELECT COUNT(*) FROM complaints WHERE society_id = p_society_id),
    'open_complaints',     (SELECT COUNT(*) FROM complaints WHERE society_id = p_society_id AND status NOT IN ('Closed','Resolved')),
    'sla_breached',        (SELECT COUNT(*) FROM complaints WHERE society_id = p_society_id AND sla_deadline < now() AND status NOT IN ('Closed','Resolved')),
    'pending_dues_total',  (SELECT COALESCE(SUM(total_amount),0) FROM maintenance_dues WHERE society_id = p_society_id AND status IN ('pending','overdue')),
    'collection_rate',     (SELECT
                              CASE WHEN (SELECT COUNT(*) FROM maintenance_dues WHERE society_id = p_society_id) = 0 THEN 0
                              ELSE ROUND(100.0 * (SELECT COUNT(*) FROM maintenance_dues WHERE society_id = p_society_id AND status = 'paid') /
                                   (SELECT COUNT(*) FROM maintenance_dues WHERE society_id = p_society_id), 1)
                              END),
    'active_members',      (SELECT COUNT(*) FROM profiles WHERE society_id = p_society_id AND is_active = true),
    'upcoming_events',     (SELECT COUNT(*) FROM events WHERE society_id = p_society_id AND starts_at > now()),
    'pending_bookings',    (SELECT COUNT(*) FROM facility_bookings fb JOIN facilities f ON f.id = fb.facility_id WHERE f.society_id = p_society_id AND fb.status = 'pending'),
    'occupied_units',      (SELECT COUNT(*) FROM units WHERE society_id = p_society_id AND occupancy_status != 'vacant'),
    'vacant_units',        (SELECT COUNT(*) FROM units WHERE society_id = p_society_id AND occupancy_status = 'vacant'),
    'visitors_today',      (SELECT COUNT(*) FROM visitor_logs WHERE society_id = p_society_id AND entry_time::date = CURRENT_DATE),
    'onboarding_pending',  (SELECT COUNT(*) FROM onboarding_requests WHERE society_id = p_society_id AND status IN ('pending','under_review'))
  ) INTO result;
  RETURN result;
END;
$$;
