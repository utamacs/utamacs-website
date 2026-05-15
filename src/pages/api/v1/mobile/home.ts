export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/mobile/home
// Aggregates home screen data in a single request to minimise mobile round trips.
// Supports Bearer header (mobile) and cookie (web).
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();

    const [
      duesResult,
      complaintsResult,
      noticesResult,
      eventsResult,
      gateResult,
      notifResult,
    ] = await Promise.all([
      // Earliest pending due for this unit (null if nothing outstanding)
      user.unitId
        ? sb
            .from('dues')
            .select('id, amount, due_date, status, billing_periods(name)')
            .eq('society_id', SOCIETY_ID)
            .eq('unit_id', user.unitId)
            .eq('status', 'pending')
            .order('due_date', { ascending: true })
            .limit(1)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),

      // Open complaint count for this member
      sb
        .from('complaints')
        .select('id', { count: 'exact', head: true })
        .eq('society_id', SOCIETY_ID)
        .eq('raised_by', user.id)
        .in('status', ['Open', 'Assigned', 'In_Progress', 'Waiting_for_User', 'Reopened']),

      // 3 most recent published notices
      sb
        .from('notices')
        .select('id, title, published_at, is_urgent')
        .eq('society_id', SOCIETY_ID)
        .eq('status', 'published')
        .order('published_at', { ascending: false })
        .limit(3),

      // Next 2 upcoming events
      sb
        .from('events')
        .select('id, title, starts_at, location')
        .eq('society_id', SOCIETY_ID)
        .gte('starts_at', new Date().toISOString())
        .order('starts_at', { ascending: true })
        .limit(2),

      // Pending visitor gate requests for this unit
      user.unitId
        ? sb
            .from('visitor_gate_requests')
            .select('id, visitor_name, requested_at, expires_at')
            .eq('society_id', SOCIETY_ID)
            .eq('host_unit_id', user.unitId)
            .eq('status', 'pending')
            .order('requested_at', { ascending: false })
            .limit(3)
        : Promise.resolve({ data: [], error: null }),

      // Unread notification count
      sb
        .from('notifications')
        .select('id', { count: 'exact', head: true })
        .eq('society_id', SOCIETY_ID)
        .eq('user_id', user.id)
        .eq('is_read', false),
    ]);

    return Response.json({
      dues_summary: duesResult.data ?? null,
      open_complaints: complaintsResult.count ?? 0,
      recent_notices: noticesResult.data ?? [],
      upcoming_events: eventsResult.data ?? [],
      pending_gate_requests: (gateResult as { data: unknown[] | null }).data ?? [],
      unread_notifications: notifResult.count ?? 0,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
