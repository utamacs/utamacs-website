export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const isExec = ['executive', 'admin'].includes(user.role ?? '') ||
                   ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
                   user.isAdmin;
    const now = new Date().toISOString();

    const [noticesRes, notifRes, complaintsRes, slaRes, onboardRes, feedbackRes] = await Promise.all([
      // Unread notices: published, not expired, newer than 30 days
      sb.from('notices')
        .select('id', { count: 'exact', head: true })
        .eq('society_id', SOCIETY_ID)
        .eq('is_published', true)
        .or(`expires_at.is.null,expires_at.gt.${now}`)
        .gte('published_at', new Date(Date.now() - 30 * 86400000).toISOString()),

      // Unread personal notifications
      sb.from('notifications')
        .select('id', { count: 'exact', head: true })
        .eq('society_id', SOCIETY_ID)
        .eq('user_id', user.id)
        .eq('is_read', false),

      // Open complaints (exec: all open; member: own open)
      isExec
        ? sb.from('complaints')
            .select('id', { count: 'exact', head: true })
            .eq('society_id', SOCIETY_ID)
            .in('status', ['Open', 'Assigned', 'In_Progress', 'Waiting_for_User', 'Reopened'])
        : Promise.resolve({ count: 0, error: null }),

      // SLA-breached complaints (exec only)
      isExec
        ? sb.from('complaints')
            .select('id', { count: 'exact', head: true })
            .eq('society_id', SOCIETY_ID)
            .eq('sla_breached', true)
            .in('status', ['Open', 'Assigned', 'In_Progress', 'Waiting_for_User', 'Reopened'])
        : Promise.resolve({ count: 0, error: null }),

      // Pending onboarding / registration requests (exec only)
      isExec
        ? sb.from('membership_applications')
            .select('id', { count: 'exact', head: true })
            .eq('society_id', SOCIETY_ID)
            .eq('status', 'pending')
        : Promise.resolve({ count: 0, error: null }),

      // Unread feedback submissions (exec only)
      isExec
        ? sb.from('feedback')
            .select('id', { count: 'exact', head: true })
            .eq('society_id', SOCIETY_ID)
            .eq('is_reviewed', false)
        : Promise.resolve({ count: 0, error: null }),
    ]);

    return Response.json({
      unread_notices:       noticesRes.count ?? 0,
      unread_notifications: notifRes.count ?? 0,
      open_complaints:      complaintsRes.count ?? 0,
      sla_breached:         slaRes.count ?? 0,
      onboarding_pending:   onboardRes.count ?? 0,
      unread_feedback:      feedbackRes.count ?? 0,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
