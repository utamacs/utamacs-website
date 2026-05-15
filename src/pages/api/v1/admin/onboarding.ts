export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/admin/onboarding?status=pending&type=owner&page=1
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin && !['executive', 'secretary', 'president'].includes(user.portalRole ?? '')) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const status = url.searchParams.get('status') || null;
    const type   = url.searchParams.get('type') || null;
    const page   = Math.max(1, parseInt(url.searchParams.get('page') ?? '1'));
    const limit  = 25;
    const offset = (page - 1) * limit;

    const sb = getSupabaseServiceClient();
    let query = sb
      .from('onboarding_requests')
      .select('id, request_type, status, applicant_name, applicant_email, applicant_phone, unit_number, block, ownership_doc_key, lease_doc_key, lease_start, lease_end, relationship, reviewed_by, reviewed_at, rejection_reason, notes, expires_at, created_at', { count: 'exact' })
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) query = query.eq('status', status);
    if (type)   query = query.eq('request_type', type);

    const { data, error, count } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ requests: data ?? [], total: count ?? 0, page, limit }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH /api/v1/admin/onboarding — update a single request
// Body: { id, status, notes?, rejection_reason? }
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin && !['executive', 'secretary', 'president'].includes(user.portalRole ?? '')) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const body = await request.json() as {
      id?: string;
      status?: string;
      notes?: string;
      rejection_reason?: string;
    };

    if (!body.id) {
      return Response.json({ error: 'VALIDATION', message: 'id is required' }, { status: 400 });
    }

    const VALID_STATUSES = ['pending', 'under_review', 'approved', 'rejected', 'expired'];
    if (!body.status || !VALID_STATUSES.includes(body.status)) {
      return Response.json({ error: 'VALIDATION', message: `status must be one of: ${VALID_STATUSES.join(', ')}` }, { status: 400 });
    }

    if (body.status === 'rejected' && !body.rejection_reason?.trim()) {
      return Response.json({ error: 'VALIDATION', message: 'rejection_reason is required when rejecting' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing, error: fetchErr } = await sb
      .from('onboarding_requests')
      .select('id, status, applicant_email, applicant_name, request_type')
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) {
      return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    }

    const updates: Record<string, unknown> = {
      status:           body.status,
      reviewed_by:      user.id,
      reviewed_at:      new Date().toISOString(),
      notes:            body.notes ? sanitizePlainText(body.notes) : null,
      rejection_reason: body.rejection_reason ? sanitizePlainText(body.rejection_reason) : null,
    };

    const { error: updateErr } = await sb
      .from('onboarding_requests')
      .update(updates)
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID);

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // If approved, invite via Supabase Auth
    if (body.status === 'approved') {
      const sb2 = getSupabaseServiceClient();
      const { error: inviteErr } = await sb2.auth.admin.inviteUserByEmail(existing.applicant_email, {
        data: {
          society_id:    SOCIETY_ID,
          onboarding_id: existing.id,
          request_type:  existing.request_type,
          full_name:     existing.applicant_name,
        },
        redirectTo: `${import.meta.env.PUBLIC_PORTAL_URL ?? 'https://portal.utamacs.org'}/portal/onboarding/complete`,
      });
      if (inviteErr) {
        console.error('[onboarding] invite failed:', inviteErr.message);
      }
    }

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       'UPDATE',
      resourceType: 'onboarding_requests',
      resourceId:   body.id,
      ip:           extractClientIP(request),
      oldValues:    { status: existing.status },
      newValues:    { status: body.status, rejection_reason: body.rejection_reason },
    });

    return Response.json({ ok: true, id: body.id, status: body.status }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
