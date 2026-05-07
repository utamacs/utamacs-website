export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const VALID_STATUSES = ['approved', 'rejected', 'duplicate'] as const;

function isPrivileged(role: string, portalRole?: string, isAdmin?: boolean) {
  if (isAdmin) return true;
  return ['executive', 'admin'].includes(role) ||
    ['executive', 'secretary', 'president'].includes(portalRole ?? '');
}

// GET /api/v1/admin/registrations?status=pending&limit=50&offset=0
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (!isPrivileged(user.role, user.portalRole, user.isAdmin)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const status = url.searchParams.get('status') ?? '';
    const limit  = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 200);
    const offset = parseInt(url.searchParams.get('offset') ?? '0');

    const sb = getSupabaseServiceClient();
    let query = sb
      .from('registration_requests')
      .select(`
        id, full_name, email, phone, occupancy_type,
        id_type, id_doc_key,
        vehicle_reg_no, vehicle_make, move_in_date,
        status, reviewed_at, rejection_reason, created_at,
        units(unit_number, block)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) query = query.eq('status', status);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'EXPORT', resourceType: 'registration_requests', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      newValues: { status_filter: status || 'all', count: data?.length },
    });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH /api/v1/admin/registrations  { id, status, rejection_reason? }
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!isPrivileged(user.role, user.portalRole, user.isAdmin)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const body = await request.json() as { id?: string; status?: string; rejection_reason?: string };

    if (!body.id || !UUID_RE.test(body.id)) {
      return Response.json({ error: 'VALIDATION', message: 'Valid request id required' }, { status: 400 });
    }
    if (!body.status || !VALID_STATUSES.includes(body.status as typeof VALID_STATUSES[number])) {
      return Response.json({ error: 'VALIDATION', message: 'status must be approved | rejected | duplicate' }, { status: 400 });
    }
    if (body.status === 'rejected' && !body.rejection_reason?.trim()) {
      return Response.json({ error: 'VALIDATION', message: 'rejection_reason is required when rejecting' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: before, error: fetchErr } = await sb
      .from('registration_requests')
      .select('id, status, full_name, email')
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !before) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (before.status !== 'pending') {
      return Response.json({ error: 'CONFLICT', message: 'Request is already reviewed' }, { status: 409 });
    }

    const updates: Record<string, unknown> = {
      status: body.status,
      reviewed_by: user.id,
      reviewed_at: new Date().toISOString(),
    };
    if (body.rejection_reason) {
      updates.rejection_reason = sanitizePlainText(body.rejection_reason).trim().slice(0, 500);
    }

    const { data, error } = await sb
      .from('registration_requests')
      .update(updates)
      .eq('id', body.id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'registration_request', resourceId: body.id,
      ip: extractClientIP(request),
      oldValues: { status: before.status },
      newValues: { status: body.status, rejection_reason: updates.rejection_reason },
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
