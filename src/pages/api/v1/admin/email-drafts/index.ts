export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list email drafts (secretary+ or admin)
// Query: status (DRAFT|REVIEWED|SENT|DISCARDED), tier, limit
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });

    // Secretary, president, or admin can view drafts
    const canView = ['secretary','president'].includes(user.portalRole) || user.isAdmin;
    if (!canView) return Response.json({ error: 'FORBIDDEN', message: 'Secretary or admin access required' }, { status: 403 });

    const url = new URL(request.url);
    const status = url.searchParams.get('status') ?? '';
    const tier   = url.searchParams.get('tier')   ?? '';
    const limit  = Math.min(Number(url.searchParams.get('limit') ?? '50'), 200);

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('email_drafts')
      .select('id, tier, triggered_by, trigger_resource_type, trigger_resource_id, recipient_type, recipient_email, recipient_name, subject, body_text, status, created_at, sent_at, discarded_reason')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(limit);

    // Default to showing only Tier 3 (manual review required) unless filtered
    if (status) query = query.eq('status', status);
    else query = query.eq('status', 'DRAFT');
    if (tier) query = query.eq('tier', Number(tier));
    else query = query.eq('tier', 3);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
