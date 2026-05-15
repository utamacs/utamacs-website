export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_FREQUENCIES = ['daily','weekly','fortnightly','monthly','quarterly','half_yearly','annual'] as const;

function requireExec(user: { isAdmin: boolean; portalRole?: string | null }) {
  return user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
}

// PATCH /api/v1/admin/ppm/[id] — update schedule (title, frequency, notes, is_active)
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const scheduleId = params.id ?? '';
    if (!UUID_RE.test(scheduleId))
      return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const body = await request.json() as Record<string, unknown>;
    const patch: Record<string, unknown> = {};

    if (body.title !== undefined)            patch.title            = String(body.title).trim().slice(0, 200);
    if (body.description !== undefined)      patch.description      = body.description ? String(body.description).trim() : null;
    if (body.responsible_role !== undefined) patch.responsible_role = body.responsible_role ? String(body.responsible_role).slice(0, 100) : null;
    if (body.notes !== undefined)            patch.notes            = body.notes ? String(body.notes).trim() : null;
    if (body.is_active !== undefined)        patch.is_active        = Boolean(body.is_active);
    if (body.next_due_date !== undefined)    patch.next_due_date    = body.next_due_date || null;
    if (body.frequency !== undefined) {
      const freq = String(body.frequency);
      if (!VALID_FREQUENCIES.includes(freq as any))
        return Response.json({ error: 'VALIDATION', message: 'Invalid frequency' }, { status: 400 });
      patch.frequency = freq;
    }
    if (body.frequency_days !== undefined) {
      const fd = Number(body.frequency_days);
      if (fd < 1) return Response.json({ error: 'VALIDATION', message: 'frequency_days must be >= 1' }, { status: 400 });
      patch.frequency_days = fd;
    }

    if (!Object.keys(patch).length) return Response.json({ error: 'VALIDATION', message: 'No fields to update' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('ppm_schedules')
      .update(patch)
      .eq('id', scheduleId)
      .eq('society_id', SOCIETY_ID)
      .select('id, title, frequency, next_due_date, is_active')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    if (!data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    await writeAuditLog(sb, {
      societyId:    SOCIETY_ID,
      actorId:      user.id,
      action:       'UPDATE',
      resourceType: 'ppm_schedules',
      resourceId:   scheduleId,
      newValues:    patch,
      ipAddress:    extractClientIP(request),
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/admin/ppm/[id] — soft-delete (is_active = false)
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const scheduleId = params.id ?? '';
    if (!UUID_RE.test(scheduleId))
      return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('ppm_schedules')
      .update({ is_active: false })
      .eq('id', scheduleId)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog(sb, {
      societyId:    SOCIETY_ID,
      actorId:      user.id,
      action:       'DELETE',
      resourceType: 'ppm_schedules',
      resourceId:   scheduleId,
      newValues:    { is_active: false },
      ipAddress:    extractClientIP(request),
    });

    return Response.json({ ok: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
