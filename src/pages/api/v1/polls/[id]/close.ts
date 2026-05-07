export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** POST /api/v1/polls/:id/close — immediately closes a poll by setting ends_at to now (exec only). */
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const pollId = params.id ?? '';
    if (!UUID_RE.test(pollId)) return Response.json({ error: 'Invalid poll id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const closedAt = new Date().toISOString();

    const { data, error } = await sb
      .from('polls')
      .update({ ends_at: closedAt })
      .eq('id', pollId)
      .eq('society_id', SOCIETY_ID)
      .select('id, ends_at')
      .single();

    if (error || !data) return Response.json({ error: 'Poll not found' }, { status: 404 });

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'polls', resourceId: pollId,
      ip: extractClientIP(request),
      newValues: { ends_at: closedAt, action: 'manually_closed' },
    });

    return Response.json({ success: true, ends_at: data.ends_at });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
