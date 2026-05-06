export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST — finalize vendor selection (dual sign-off: both president + secretary must have vendor.final_select)
// Body: { vendor_id, notes? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.final_select');

    const reqId = params.id!;
    const body = await request.json() as { vendor_id?: string; notes?: string };

    if (!body.vendor_id?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'vendor_id is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: req } = await sb
      .from('vendor_requirements')
      .select('*')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!req) return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });

    if ((req as any).status !== 'VOTING_CLOSED') {
      return Response.json({
        error: 'CONFLICT',
        message: 'Final selection can only be made after voting is closed',
      }, { status: 409 });
    }

    // Verify candidate belongs to this requirement
    const { data: candidate } = await sb
      .from('vendor_candidates')
      .select('id, vendor_name')
      .eq('id', body.vendor_id)
      .eq('requirement_id', reqId)
      .single();

    if (!candidate) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: 'vendor_id does not belong to this requirement',
      }, { status: 400 });
    }

    const { data: updated, error } = await sb
      .from('vendor_requirements')
      .update({
        status: 'FINALIST_SELECTED',
        selected_vendor_id: body.vendor_id,
      })
      .eq('id', reqId)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'STATUS_CHANGE',
        resource_type: 'vendor_requirements',
        resource_id: reqId,
        old_values: { status: 'VOTING_CLOSED' },
        new_values: {
          status: 'FINALIST_SELECTED',
          selected_vendor_id: body.vendor_id,
          vendor_name: (candidate as any).vendor_name,
          notes: body.notes ?? null,
        },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'UPDATE', resourceType: 'vendor_requirements', resourceId: reqId,
        ip: extractClientIP(request),
        newValues: { status: 'FINALIST_SELECTED', selected_vendor_id: body.vendor_id },
      }),
    ]);

    return Response.json(updated);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
