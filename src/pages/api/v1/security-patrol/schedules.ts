export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_SHIFTS = ['morning', 'afternoon', 'evening', 'night', 'full_day'] as const;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// GET /api/v1/security-patrol/schedules — list active/upcoming schedules
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const activeOnly = url.searchParams.get('active') !== 'false';
    const today = new Date().toISOString().slice(0, 10);

    let query = sb
      .from('patrol_schedules')
      .select('id, guard_name, shift, days_of_week, effective_from, effective_to, notes, created_at')
      .eq('society_id', SOCIETY_ID)
      .order('effective_from', { ascending: false });

    if (activeOnly) {
      query = query
        .lte('effective_from', today)
        .or(`effective_to.is.null,effective_to.gte.${today}`);
    }

    const { data, error } = await query.limit(200);
    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/security-patrol/schedules — create schedule entry (exec only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const guard_name    = sanitizePlainText(String(body.guard_name ?? '')).trim();
    const shift         = String(body.shift ?? '');
    const days_of_week  = body.days_of_week;
    const effective_from = String(body.effective_from ?? '');
    const effective_to   = body.effective_to ? String(body.effective_to) : null;
    const notes          = body.notes ? sanitizePlainText(String(body.notes)).trim().slice(0, 300) : null;

    if (!guard_name) return Response.json({ error: 'VALIDATION', message: 'guard_name is required' }, { status: 400 });
    if (!VALID_SHIFTS.includes(shift as typeof VALID_SHIFTS[number])) {
      return Response.json({ error: 'VALIDATION', message: `shift must be one of: ${VALID_SHIFTS.join(', ')}` }, { status: 400 });
    }
    if (!Array.isArray(days_of_week) || days_of_week.length === 0) {
      return Response.json({ error: 'VALIDATION', message: 'days_of_week must be a non-empty array of 0–6' }, { status: 400 });
    }
    const parsedDays = (days_of_week as unknown[]).map(d => Number(d)).filter(d => Number.isInteger(d) && d >= 0 && d <= 6);
    if (parsedDays.length !== days_of_week.length) {
      return Response.json({ error: 'VALIDATION', message: 'days_of_week values must be integers 0–6' }, { status: 400 });
    }
    if (!DATE_RE.test(effective_from)) {
      return Response.json({ error: 'VALIDATION', message: 'effective_from must be YYYY-MM-DD' }, { status: 400 });
    }
    if (effective_to && !DATE_RE.test(effective_to)) {
      return Response.json({ error: 'VALIDATION', message: 'effective_to must be YYYY-MM-DD' }, { status: 400 });
    }
    if (effective_to && effective_to < effective_from) {
      return Response.json({ error: 'VALIDATION', message: 'effective_to must be on or after effective_from' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('patrol_schedules')
      .insert({
        society_id:     SOCIETY_ID,
        guard_name,
        shift,
        days_of_week:   parsedDays,
        effective_from,
        effective_to:   effective_to ?? null,
        notes:          notes ?? null,
        created_by:     user.id,
      })
      .select()
      .single();

    if (error) throw error;

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'patrol_schedules', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { guard_name, shift, days_of_week: parsedDays, effective_from, effective_to },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/security-patrol/schedules?id=<uuid> (exec only)
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = url.searchParams.get('id') ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Valid id required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb.from('patrol_schedules').delete().eq('id', id).eq('society_id', SOCIETY_ID);
    if (error) throw error;

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
