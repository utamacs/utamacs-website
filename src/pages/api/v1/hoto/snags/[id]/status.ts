export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import type { Feature } from '@lib/features';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// Status machine:
// OPEN → IN_PROGRESS (snag.create)
// IN_PROGRESS → RESOLVED (snag.create)
// RESOLVED → VERIFIED_CLOSED (snag.verify_close — secretary/president only)
// VERIFIED_CLOSED → REOPENED (snag.create, mandatory reopen_reason)
// REOPENED → IN_PROGRESS (snag.create)
const TRANSITIONS: Record<string, { from: string[]; feature: Feature; requiresReopenReason?: boolean }> = {
  IN_PROGRESS:     { from: ['OPEN', 'REOPENED'],    feature: 'snag.create' },
  RESOLVED:        { from: ['IN_PROGRESS'],         feature: 'snag.create' },
  VERIFIED_CLOSED: { from: ['RESOLVED'],            feature: 'snag.verify_close' },
  REOPENED:        { from: ['VERIFIED_CLOSED'],     feature: 'snag.create', requiresReopenReason: true },
};

// POST — advance snag status
// Body: { to_status, reopen_reason? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });

    const snagId = params.id!;
    const body = await request.json() as { to_status?: string; reopen_reason?: string };

    if (!body.to_status) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'to_status is required' }, { status: 400 });
    }

    const transition = TRANSITIONS[body.to_status];
    if (!transition) {
      return Response.json({ error: 'VALIDATION_ERROR', message: `Unknown target status: ${body.to_status}` }, { status: 400 });
    }

    requireFeature(user, transition.feature);

    if (transition.requiresReopenReason && !body.reopen_reason?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'reopen_reason is required when reopening a snag' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: snag } = await sb
      .from('snag_items')
      .select('id, status, deleted')
      .eq('id', snagId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!snag || (snag as any).deleted) {
      return Response.json({ error: 'NOT_FOUND', message: 'Snag item not found' }, { status: 404 });
    }

    if (!transition.from.includes((snag as any).status)) {
      return Response.json({
        error: 'CONFLICT',
        message: `Cannot transition from ${(snag as any).status} to ${body.to_status}`,
      }, { status: 409 });
    }

    const extraUpdates: Record<string, unknown> = {};
    if (body.to_status === 'VERIFIED_CLOSED') {
      extraUpdates.verified_by = user.id;
      extraUpdates.verified_at = new Date().toISOString();
    }
    if (body.to_status === 'REOPENED' && body.reopen_reason) {
      extraUpdates.reopen_reason = body.reopen_reason.trim();
    }

    const { data: updated, error } = await sb
      .from('snag_items')
      .update({ status: body.to_status, ...extraUpdates })
      .eq('id', snagId)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'STATUS_CHANGE',
        resource_type: 'snag_items',
        resource_id: snagId,
        old_values: { status: (snag as any).status },
        new_values: {
          status: body.to_status,
          ...(body.reopen_reason ? { reopen_reason: body.reopen_reason.trim() } : {}),
        },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'UPDATE', resourceType: 'snag_items', resourceId: snagId,
        ip: extractClientIP(request),
        newValues: { status: body.to_status },
      }),
    ]);

    return Response.json(updated);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
