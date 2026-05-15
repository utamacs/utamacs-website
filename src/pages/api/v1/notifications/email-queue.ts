export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/notifications/email-queue — exec/admin only
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const statusFilter = url.searchParams.get('status'); // pending | sent | failed
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);

    const sb = getSupabaseServiceClient();
    let query = sb
      .from('email_queue')
      .select('id, to_email, subject, status, retry_count, max_retries, scheduled_for, sent_at, last_error, created_at')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (statusFilter) query = query.eq('status', statusFilter);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ rows: data ?? [] });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
