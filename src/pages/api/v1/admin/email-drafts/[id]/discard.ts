export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST — discard a draft email (secretary+ or admin)
// Body: { discarded_reason }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });

    const canDiscard = ['secretary','president'].includes(user.portalRole) || user.isAdmin;
    if (!canDiscard) return Response.json({ error: 'FORBIDDEN', message: 'Secretary or admin required' }, { status: 403 });

    const body = await request.json() as { discarded_reason?: string };
    if (!body.discarded_reason?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'discarded_reason is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('email_drafts')
      .select('id, status')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing) return Response.json({ error: 'NOT_FOUND', message: 'Draft not found' }, { status: 404 });

    if (!['DRAFT','REVIEWED'].includes((existing as any).status)) {
      return Response.json({ error: 'CONFLICT', message: `Cannot discard a draft with status: ${(existing as any).status}` }, { status: 409 });
    }

    const { data: updated, error } = await sb
      .from('email_drafts')
      .update({
        status: 'DISCARDED',
        discarded_by: user.id,
        discarded_reason: body.discarded_reason.trim(),
      })
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'email_drafts', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { status: 'DISCARDED', reason: body.discarded_reason.trim() },
    });

    return Response.json(updated);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
