export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// DELETE — revoke a per-user feature override (admin only)
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin access required' }, { status: 403 });

    const targetUserId = params.id!;
    const feature = params.feature!;

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('user_feature_overrides')
      .select('id')
      .eq('user_id', targetUserId)
      .eq('feature', feature)
      .eq('society_id', SOCIETY_ID)
      .is('revoked_at', null)
      .single();

    if (!existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'Active override not found' }, { status: 404 });
    }

    const { error } = await sb
      .from('user_feature_overrides')
      .update({ revoked_at: new Date().toISOString(), revoked_by: user.id })
      .eq('id', (existing as any).id);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DELETE', resourceType: 'user_feature_overrides', resourceId: targetUserId,
      ip: extractClientIP(request),
      newValues: { feature, action: 'REVOKED' },
    });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
