export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — full requirement detail with candidates + vote summary
// Auth: vendor.view
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.view');

    const reqId = params.id!;
    const sb = getSupabaseServiceClient();

    const [reqRes, candidatesRes, votesRes] = await Promise.all([
      sb.from('vendor_requirements')
        .select('*')
        .eq('id', reqId)
        .eq('society_id', SOCIETY_ID)
        .single(),

      sb.from('vendor_candidates')
        .select('*')
        .eq('requirement_id', reqId)
        .order('submitted_at', { ascending: true }),

      sb.from('votes')
        .select('id, voter_id, vendor_id, reason, conflict_declared, recused, cast_at')
        .eq('requirement_id', reqId),
    ]);

    if (reqRes.error || !reqRes.data) {
      return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });
    }

    // Check if current user has voted
    const userVote = votesRes.data?.find(v => v.voter_id === user.id) ?? null;

    // Vote tally per candidate
    const voteTally: Record<string, number> = {};
    const totalVotes = votesRes.data?.length ?? 0;
    for (const v of votesRes.data ?? []) {
      if (v.vendor_id && !v.recused) {
        voteTally[v.vendor_id] = (voteTally[v.vendor_id] ?? 0) + 1;
      }
    }

    return Response.json({
      requirement: reqRes.data,
      candidates: candidatesRes.data ?? [],
      vote_summary: {
        total_votes: totalVotes,
        tally: voteTally,
        user_vote: userVote,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — update requirement metadata (auth: vendor.create, DRAFT status only)
// Body: { title?, description?, category?, quorum_required?, voting_policy_committed? }
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.create');

    const reqId = params.id!;
    const sb = getSupabaseServiceClient();

    const { data: existing, error: fetchErr } = await sb
      .from('vendor_requirements')
      .select('id, status')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });
    }

    if ((existing as any).status !== 'DRAFT') {
      return Response.json({
        error: 'CONFLICT',
        message: 'Metadata can only be edited in DRAFT status',
      }, { status: 409 });
    }

    const body = await request.json() as Record<string, unknown>;
    const allowed = ['title', 'description', 'category', 'quorum_required', 'voting_policy_committed'];
    const updates: Record<string, unknown> = {};
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No updatable fields provided' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('vendor_requirements')
      .update(updates)
      .eq('id', reqId)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'vendor_requirements', resourceId: reqId,
      ip: extractClientIP(request),
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
