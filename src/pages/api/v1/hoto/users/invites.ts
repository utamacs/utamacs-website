export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireAdmin } from '@lib/permissions';
import { loadRules, r, RULE } from '@lib/rules';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET  — list all invites (pending, accepted, cancelled, expired)
// POST — resend an invite: extends token_expires_at and refreshes token
// Auth: admin required for both
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireAdmin(user);

    const sb = getSupabaseServiceClient();
    const statusFilter = url.searchParams.get('status'); // 'pending' | 'accepted' | 'cancelled' | 'expired'
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);

    const now = new Date().toISOString();
    let query = sb
      .from('member_invites')
      .select('id, email, flat_number, intended_role, token_expires_at, accepted, accepted_at, cancelled, cancelled_by, created_at, invited_by')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (statusFilter === 'pending') {
      query = query.eq('accepted', false).eq('cancelled', false).gte('token_expires_at', now);
    } else if (statusFilter === 'accepted') {
      query = query.eq('accepted', true);
    } else if (statusFilter === 'cancelled') {
      query = query.eq('cancelled', true);
    } else if (statusFilter === 'expired') {
      query = query.eq('accepted', false).eq('cancelled', false).lt('token_expires_at', now);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Annotate each invite with computed status
    const invites = (data ?? []).map((inv: any) => ({
      ...inv,
      status: inv.accepted ? 'ACCEPTED'
        : inv.cancelled ? 'CANCELLED'
        : inv.token_expires_at < now ? 'EXPIRED'
        : 'PENDING',
    }));

    return Response.json({ invites });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — resend (refresh) an existing invite
// Body: { invite_id }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireAdmin(user);

    const body = await request.json() as { invite_id?: string };
    if (!body.invite_id) return Response.json({ error: 'VALIDATION_ERROR', message: 'invite_id is required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const rules = await loadRules(SOCIETY_ID);
    const expiryDays = r<number>(rules, RULE.INVITE_EXPIRY_DAYS, 7);

    // Verify invite exists and is resendable
    const { data: existing } = await sb
      .from('member_invites').select('id, email, accepted, cancelled')
      .eq('id', body.invite_id).eq('society_id', SOCIETY_ID).single();

    if (!existing) return Response.json({ error: 'NOT_FOUND', message: 'Invite not found' }, { status: 404 });
    if ((existing as any).accepted) return Response.json({ error: 'CONFLICT', message: 'Invite already accepted' }, { status: 409 });
    if ((existing as any).cancelled) return Response.json({ error: 'CONFLICT', message: 'Invite was cancelled' }, { status: 409 });

    // Refresh token and extend expiry
    const newExpiry = new Date(Date.now() + expiryDays * 86_400_000).toISOString();
    const { data: updated, error } = await sb
      .from('member_invites')
      .update({
        token: Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString('hex'),
        token_expires_at: newExpiry,
      })
      .eq('id', body.invite_id)
      .select('id, email, flat_number, token_expires_at')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ invite: updated, resent: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE — cancel an invite
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireAdmin(user);

    const inviteId = url.searchParams.get('invite_id');
    if (!inviteId) return Response.json({ error: 'VALIDATION_ERROR', message: 'invite_id query param required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('member_invites')
      .update({ cancelled: true, cancelled_by: user.id, cancelled_at: new Date().toISOString() })
      .eq('id', inviteId).eq('society_id', SOCIETY_ID).eq('accepted', false);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
