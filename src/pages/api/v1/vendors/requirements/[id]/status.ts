export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import type { Feature } from '@lib/features';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// Status machine transitions
// to_status → from_status(es) + required feature
const TRANSITIONS: Record<string, { from: string[]; feature: Feature; extraCheck?: string }> = {
  OPEN_FOR_QUOTES:   { from: ['DRAFT'],            feature: 'vendor.advance_status', extraCheck: 'policyCommitted' },
  VOTING_OPEN:       { from: ['OPEN_FOR_QUOTES'],  feature: 'vendor.advance_status', extraCheck: 'hasCandidates' },
  VOTING_CLOSED:     { from: ['VOTING_OPEN'],      feature: 'vendor.advance_status' },
  FINALIST_SELECTED: { from: ['VOTING_CLOSED'],    feature: 'vendor.final_select' },
  CONTRACT_SIGNED:   { from: ['FINALIST_SELECTED'], feature: 'vendor.final_select' },
  CANCELLED:         { from: ['DRAFT', 'OPEN_FOR_QUOTES', 'VOTING_OPEN', 'VOTING_CLOSED'], feature: 'vendor.advance_status' },
};

// POST — advance requirement status
// Auth: feature-gated per transition (secretary+ for most, dual sign-off for FINALIST_SELECTED)
// Body: { to_status, notes? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });

    const reqId = params.id!;
    const body = await request.json() as { to_status?: string; notes?: string };

    if (!body.to_status) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'to_status is required' }, { status: 400 });
    }

    const transition = TRANSITIONS[body.to_status];
    if (!transition) {
      return Response.json({ error: 'VALIDATION_ERROR', message: `Unknown target status: ${body.to_status}` }, { status: 400 });
    }

    requireFeature(user, transition.feature);

    const sb = getSupabaseServiceClient();

    const { data: req, error: fetchErr } = await sb
      .from('vendor_requirements')
      .select('*')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !req) {
      return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });
    }

    if (!transition.from.includes((req as any).status)) {
      return Response.json({
        error: 'CONFLICT',
        message: `Cannot transition from ${(req as any).status} to ${body.to_status}`,
      }, { status: 409 });
    }

    // Extra checks per transition
    if (transition.extraCheck === 'policyCommitted' && !(req as any).voting_policy_committed) {
      return Response.json({
        error: 'PRECONDITION_FAILED',
        message: 'Voting policy must be committed before opening for quotes',
      }, { status: 422 });
    }

    if (transition.extraCheck === 'hasCandidates') {
      const { count } = await sb
        .from('vendor_candidates')
        .select('id', { count: 'exact', head: true })
        .eq('requirement_id', reqId);
      if (!count || count < 1) {
        return Response.json({
          error: 'PRECONDITION_FAILED',
          message: 'At least one candidate must be added before opening voting',
        }, { status: 422 });
      }
    }

    const extraUpdates: Record<string, unknown> = {};
    if (body.to_status === 'VOTING_OPEN') {
      extraUpdates.voting_opens_at = new Date().toISOString();
    }
    if (body.to_status === 'VOTING_CLOSED') {
      extraUpdates.voting_closes_at = new Date().toISOString();
    }

    const { data: updated, error: updateErr } = await sb
      .from('vendor_requirements')
      .update({ status: body.to_status, ...extraUpdates })
      .eq('id', reqId)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'STATUS_CHANGE',
        resource_type: 'vendor_requirements',
        resource_id: reqId,
        old_values: { status: (req as any).status },
        new_values: { status: body.to_status, notes: body.notes ?? null },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'UPDATE', resourceType: 'vendor_requirements', resourceId: reqId,
        ip: extractClientIP(request),
        newValues: { status: body.to_status },
      }),
    ]);

    return Response.json(updated);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
