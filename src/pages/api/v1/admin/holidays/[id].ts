export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// DELETE /api/v1/admin/holidays/:id
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin && !['executive', 'secretary', 'president'].includes(user.portalRole ?? '')) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const { id } = params;
    if (!id || !UUID_RE.test(id)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('holiday_calendar')
      .delete()
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
