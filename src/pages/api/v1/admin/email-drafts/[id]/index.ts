export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function canAccessDrafts(user: { portalRole: string; isAdmin: boolean }): boolean {
  return ['secretary','president'].includes(user.portalRole) || user.isAdmin;
}

// GET — fetch full draft including body_html (secretary+ or admin)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!canAccessDrafts(user)) return Response.json({ error: 'FORBIDDEN', message: 'Secretary or admin required' }, { status: 403 });

    const { data, error } = await getSupabaseServiceClient()
      .from('email_drafts')
      .select('*')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) return Response.json({ error: 'NOT_FOUND', message: 'Draft not found' }, { status: 404 });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — edit subject and/or body_html / body_text of a DRAFT (secretary+ or admin)
// Body: { subject?, body_html?, body_text? }
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!canAccessDrafts(user)) return Response.json({ error: 'FORBIDDEN', message: 'Secretary or admin required' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const { data: existing } = await sb
      .from('email_drafts')
      .select('id, status')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing) return Response.json({ error: 'NOT_FOUND', message: 'Draft not found' }, { status: 404 });
    if (!['DRAFT','REVIEWED'].includes((existing as any).status)) {
      return Response.json({ error: 'CONFLICT', message: 'Only DRAFT or REVIEWED emails can be edited' }, { status: 409 });
    }

    const body = await request.json() as { subject?: string; body_html?: string; body_text?: string };
    const updates: Record<string, unknown> = { reviewed_by: user.id, reviewed_at: new Date().toISOString(), status: 'REVIEWED' };
    if (body.subject !== undefined) updates.subject = body.subject;
    if (body.body_html !== undefined) updates.body_html = body.body_html;
    if (body.body_text !== undefined) updates.body_text = body.body_text;

    const { data, error } = await sb
      .from('email_drafts')
      .update(updates)
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
