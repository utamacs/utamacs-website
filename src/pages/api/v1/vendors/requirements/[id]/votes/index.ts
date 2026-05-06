export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — vote tally (auth: vendor.view)
// Returns: { total_votes, tally (per candidate), user_vote, quorum_required, quorum_met }
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.view');

    const reqId = params.id!;
    const sb = getSupabaseServiceClient();

    const [reqRes, votesRes] = await Promise.all([
      sb.from('vendor_requirements')
        .select('id, status, quorum_required, selected_vendor_id')
        .eq('id', reqId)
        .eq('society_id', SOCIETY_ID)
        .single(),
      sb.from('votes')
        .select('id, voter_id, vendor_id, reason, conflict_declared, recused, cast_at')
        .eq('requirement_id', reqId),
    ]);

    if (reqRes.error || !reqRes.data) {
      return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });
    }

    const req = reqRes.data as any;
    const votes = votesRes.data ?? [];

    const tally: Record<string, number> = {};
    let userVote = null;
    for (const v of votes) {
      if (v.voter_id === user.id) userVote = v;
      if (v.vendor_id && !v.recused) {
        tally[v.vendor_id] = (tally[v.vendor_id] ?? 0) + 1;
      }
    }

    const nonRecusedVotes = votes.filter((v: any) => !v.recused).length;

    return Response.json({
      total_votes: votes.length,
      active_votes: nonRecusedVotes,
      quorum_required: req.quorum_required,
      quorum_met: nonRecusedVotes >= req.quorum_required,
      tally,
      user_vote: userVote,
      selected_vendor_id: req.selected_vendor_id,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — cast or update vote (auth: vendor.vote)
// Body: { vendor_id? (null for financial approval / no preference), reason, conflict_declared, recused?, proxy_authorization_id? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.vote');

    const reqId = params.id!;
    const body = await request.json() as {
      vendor_id?: string | null;
      reason?: string;
      conflict_declared?: boolean;
      recused?: boolean;
      proxy_authorization_id?: string;
    };

    if (!body.reason?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'reason is required' }, { status: 400 });
    }
    if (body.conflict_declared === undefined) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'conflict_declared must be explicitly set' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify requirement is in VOTING_OPEN status
    const { data: req } = await sb
      .from('vendor_requirements')
      .select('id, status, quorum_required')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!req) return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });

    if ((req as any).status !== 'VOTING_OPEN') {
      return Response.json({
        error: 'CONFLICT',
        message: 'Voting is not currently open for this requirement',
      }, { status: 409 });
    }

    // Check payment eligibility
    const { data: profile } = await sb
      .from('profiles')
      .select('payment_status')
      .eq('id', user.id)
      .single();

    if ((profile as any)?.payment_status === 'defaulter_90d') {
      return Response.json({
        error: 'FORBIDDEN',
        message: 'Members with overdue payments of 90+ days are not eligible to vote',
      }, { status: 403 });
    }

    // If vendor_id provided, verify it belongs to this requirement
    if (body.vendor_id) {
      const { data: candidate } = await sb
        .from('vendor_candidates')
        .select('id')
        .eq('id', body.vendor_id)
        .eq('requirement_id', reqId)
        .single();

      if (!candidate) {
        return Response.json({
          error: 'VALIDATION_ERROR',
          message: 'vendor_id does not belong to this requirement',
        }, { status: 400 });
      }
    }

    // Verify proxy authorization if provided
    let effectiveVoterId = user.id;
    if (body.proxy_authorization_id) {
      const { data: proxy } = await sb
        .from('proxy_authorizations')
        .select('id, principal_user_id, proxy_user_id, requirement_id, valid_from, valid_until')
        .eq('id', body.proxy_authorization_id)
        .single();

      if (!proxy) {
        return Response.json({ error: 'NOT_FOUND', message: 'Proxy authorization not found' }, { status: 404 });
      }

      const p = proxy as any;
      if (p.proxy_user_id !== user.id) {
        return Response.json({ error: 'FORBIDDEN', message: 'Not your proxy authorization' }, { status: 403 });
      }
      if (p.requirement_id && p.requirement_id !== reqId) {
        return Response.json({ error: 'FORBIDDEN', message: 'Proxy not valid for this requirement' }, { status: 403 });
      }
      const now = new Date();
      if (new Date(p.valid_from) > now || (p.valid_until && new Date(p.valid_until) < now)) {
        return Response.json({ error: 'FORBIDDEN', message: 'Proxy authorization is not currently valid' }, { status: 403 });
      }
      effectiveVoterId = p.principal_user_id;
    }

    const voteId = `VOTE-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;

    // Upsert: one vote per voter per requirement (unique constraint)
    const { data, error } = await sb.from('votes').upsert({
      id: voteId,
      requirement_id: reqId,
      voter_id: effectiveVoterId,
      proxy_authorization_id: body.proxy_authorization_id ?? null,
      vendor_id: body.vendor_id ?? null,
      reason: body.reason.trim(),
      conflict_declared: body.conflict_declared,
      recused: body.recused ?? false,
      cast_at: new Date().toISOString(),
    }, {
      onConflict: 'requirement_id,voter_id',
      ignoreDuplicates: false,
    }).select().single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'votes', resourceId: voteId,
      ip: extractClientIP(request),
      newValues: { requirement_id: reqId, vendor_id: body.vendor_id ?? null, conflict_declared: body.conflict_declared },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
