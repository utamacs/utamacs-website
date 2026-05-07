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
const TIME_RE = /^\d{2}:\d{2}$/;

// GET /api/v1/security-patrol — list patrol logs
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const dateFrom = url.searchParams.get('from');
    const dateTo = url.searchParams.get('to');
    const incidentOnly = url.searchParams.get('incidents') === 'true';

    let query = sb
      .from('patrol_logs')
      .select('id, patrol_date, shift, guard_name, start_time, end_time, checkpoints, incidents, remarks, is_incident, created_at, created_by')
      .eq('society_id', SOCIETY_ID)
      .order('patrol_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (dateFrom && /^\d{4}-\d{2}-\d{2}$/.test(dateFrom)) query = query.gte('patrol_date', dateFrom);
    if (dateTo   && /^\d{4}-\d{2}-\d{2}$/.test(dateTo))   query = query.lte('patrol_date', dateTo);
    if (incidentOnly) query = query.eq('is_incident', true);

    const { data, error } = await query.limit(100);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/security-patrol — log a patrol entry
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    // Guards and exec can log patrols
    const canLog = user.role === 'security_guard' ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      user.isAdmin;
    if (!canLog) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const guard_name = sanitizePlainText(String(body.guard_name ?? '')).trim();
    const patrol_date = String(body.patrol_date ?? '');
    const shift = String(body.shift ?? '');

    if (!guard_name) return Response.json({ error: 'VALIDATION', message: 'guard_name required' }, { status: 400 });
    if (!/^\d{4}-\d{2}-\d{2}$/.test(patrol_date)) return Response.json({ error: 'VALIDATION', message: 'patrol_date must be YYYY-MM-DD' }, { status: 400 });
    if (!VALID_SHIFTS.includes(shift as typeof VALID_SHIFTS[number])) {
      return Response.json({ error: 'VALIDATION', message: `shift must be one of: ${VALID_SHIFTS.join(', ')}` }, { status: 400 });
    }

    const start_time = body.start_time ? String(body.start_time) : null;
    const end_time   = body.end_time   ? String(body.end_time)   : null;
    if (start_time && !TIME_RE.test(start_time)) return Response.json({ error: 'VALIDATION', message: 'start_time must be HH:MM' }, { status: 400 });
    if (end_time   && !TIME_RE.test(end_time))   return Response.json({ error: 'VALIDATION', message: 'end_time must be HH:MM' }, { status: 400 });

    const checkpoints = Array.isArray(body.checkpoints)
      ? (body.checkpoints as string[]).map(c => sanitizePlainText(String(c)).slice(0, 100)).slice(0, 20)
      : [];

    const incidents = body.incidents ? sanitizePlainText(String(body.incidents)).slice(0, 2000) : null;
    const remarks   = body.remarks   ? sanitizePlainText(String(body.remarks)).slice(0, 1000)   : null;
    const is_incident = Boolean(body.is_incident) || (incidents ? incidents.length > 0 : false);

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('patrol_logs')
      .insert({
        society_id: SOCIETY_ID,
        patrol_date,
        shift,
        guard_name,
        start_time: start_time ?? null,
        end_time:   end_time ?? null,
        checkpoints: checkpoints.length ? checkpoints : null,
        incidents: incidents ?? null,
        remarks: remarks ?? null,
        is_incident,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    if (is_incident) {
      await writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'CREATE', resourceType: 'patrol_incident', resourceId: data.id,
        ip: extractClientIP(request),
        newValues: { patrol_date, guard_name, incidents },
      });
    }

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/security-patrol?id=<uuid> (exec/admin only)
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = url.searchParams.get('id') ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Valid id required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb.from('patrol_logs').delete().eq('id', id).eq('society_id', SOCIETY_ID);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
