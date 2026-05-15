export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const unreadOnly = url.searchParams.get('unread') === 'true';
    const typeFilter = url.searchParams.get('type');
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '30'), 50);

    let query = sb
      .from('notifications')
      .select('id, title, body, type, reference_table, reference_id, is_read, read_at, created_at')
      .eq('user_id', user.id)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (unreadOnly) query = query.eq('is_read', false);
    if (typeFilter) query = query.eq('type', typeFilter);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/notifications?id=<uuid> — user deletes their own notification
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = url.searchParams.get('id') ?? '';
    if (!UUID_RE.test(id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'valid id is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify the notification belongs to this user (or exec can delete any in their society)
    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;

    let query = sb
      .from('notifications')
      .delete()
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (!isPrivileged) {
      query = query.eq('user_id', user.id);
    }

    const { error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ ok: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
