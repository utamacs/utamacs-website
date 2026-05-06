export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PATCH — update candidate metadata (auth: vendor.create)
// Can update: vendor_name, contact_person, contact_email, contact_phone, site_visited, quote_monthly, quote_setup,
//             contract_start_date, contract_end_date, renewal_reminder_sent, github_path
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.create');

    const reqId       = params.id!;
    const candidateId = params.candidateId!;
    const sb = getSupabaseServiceClient();

    // Verify candidate belongs to this requirement in this society
    const { data: candidate } = await sb
      .from('vendor_candidates')
      .select('id, requirement_id')
      .eq('id', candidateId)
      .eq('requirement_id', reqId)
      .single();

    if (!candidate) {
      return Response.json({ error: 'NOT_FOUND', message: 'Candidate not found' }, { status: 404 });
    }

    // Verify requirement belongs to this society
    const { data: req } = await sb
      .from('vendor_requirements')
      .select('id')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!req) return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });

    const body = await request.json() as Record<string, unknown>;
    const allowed = [
      'vendor_name', 'contact_person', 'contact_email', 'contact_phone',
      'site_visited', 'quote_monthly', 'quote_setup',
      'contract_start_date', 'contract_end_date', 'renewal_reminder_sent', 'github_path',
    ];
    const updates: Record<string, unknown> = {};
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No updatable fields provided' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('vendor_candidates')
      .update(updates)
      .eq('id', candidateId)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'vendor_candidates', resourceId: candidateId,
      ip: extractClientIP(request),
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE — remove a candidate (auth: vendor.create, only allowed in DRAFT or OPEN_FOR_QUOTES)
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.create');

    const reqId       = params.id!;
    const candidateId = params.candidateId!;
    const sb = getSupabaseServiceClient();

    const { data: req } = await sb
      .from('vendor_requirements')
      .select('id, status')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!req) return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });

    if (!['DRAFT', 'OPEN_FOR_QUOTES'].includes((req as any).status)) {
      return Response.json({ error: 'CONFLICT', message: 'Cannot remove candidates after voting has started' }, { status: 409 });
    }

    const { error } = await sb
      .from('vendor_candidates')
      .delete()
      .eq('id', candidateId)
      .eq('requirement_id', reqId);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DELETE', resourceType: 'vendor_candidates', resourceId: candidateId,
      ip: extractClientIP(request),
      newValues: { removed: true },
    });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
