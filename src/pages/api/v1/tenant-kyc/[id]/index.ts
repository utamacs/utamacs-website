export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const VALID_STATUSES = ['pending', 'submitted', 'police_verified', 'completed', 'expired'] as const;

const ALLOWED_STATUS_TRANSITIONS: Record<string, string[]> = {
  pending:         ['submitted', 'expired'],
  submitted:       ['police_verified', 'pending', 'expired'],
  police_verified: ['completed', 'expired'],
  completed:       ['expired'],
  expired:         [],
};

// PATCH /api/v1/tenant-kyc/:id — update status or police verification details (exec only)
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data: existing, error: fetchErr } = await sb
      .from('tenant_kyc')
      .select('id, status, full_name')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const body = await request.json() as Record<string, unknown>;
    const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };

    if (body.status !== undefined) {
      const newStatus = String(body.status);
      if (!VALID_STATUSES.includes(newStatus as typeof VALID_STATUSES[number])) {
        return Response.json({ error: 'VALIDATION', message: `Invalid status: ${newStatus}` }, { status: 400 });
      }
      const allowed = ALLOWED_STATUS_TRANSITIONS[existing.status] ?? [];
      if (!allowed.includes(newStatus)) {
        return Response.json({ error: 'VALIDATION', message: `Cannot transition from ${existing.status} to ${newStatus}` }, { status: 400 });
      }
      updates.status = newStatus;
    }

    if (body.police_verified !== undefined) updates.police_verified = Boolean(body.police_verified);
    if (body.police_station) updates.police_station = sanitizePlainText(String(body.police_station)).slice(0, 200);
    if (body.verification_date) updates.verification_date = String(body.verification_date);
    if (body.verification_ref) updates.verification_ref = sanitizePlainText(String(body.verification_ref)).slice(0, 100);
    if (body.notes !== undefined) updates.notes = body.notes ? sanitizePlainText(String(body.notes)).slice(0, 1000) : null;
    if (body.owner_consent !== undefined) {
      updates.owner_consent = Boolean(body.owner_consent);
      if (updates.owner_consent) updates.owner_consent_at = new Date().toISOString();
    }
    if (body.tenancy_end_date) updates.tenancy_end_date = String(body.tenancy_end_date);

    const { data, error } = await sb
      .from('tenant_kyc')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'tenant_kyc', resourceId: id,
      ip: extractClientIP(request),
      oldValues: { status: existing.status },
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/tenant-kyc/:id (admin only)
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb.from('tenant_kyc').delete().eq('id', id).eq('society_id', SOCIETY_ID);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
