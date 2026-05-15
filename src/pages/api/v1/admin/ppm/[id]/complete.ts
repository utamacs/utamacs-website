export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST /api/v1/admin/ppm/[id]/complete
// Marks a PPM task done: inserts ppm_completions, advances next_due_date on schedule.
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const scheduleId = params.id ?? '';
    if (!UUID_RE.test(scheduleId))
      return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const body = await request.json() as Record<string, unknown>;
    const completedOn = body.completed_on ? String(body.completed_on) : new Date().toISOString().slice(0, 10);

    const sb = getSupabaseServiceClient();

    // Fetch the schedule to compute next_due_date
    const { data: schedule, error: fetchErr } = await sb
      .from('ppm_schedules')
      .select('id, frequency_days, is_active')
      .eq('id', scheduleId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !schedule) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (!schedule.is_active) return Response.json({ error: 'VALIDATION', message: 'Schedule is inactive' }, { status: 400 });

    const nextDue = (() => {
      const d = new Date(completedOn + 'T00:00:00');
      d.setDate(d.getDate() + schedule.frequency_days);
      return d.toISOString().slice(0, 10);
    })();

    const cost = body.cost ? Number(body.cost) : null;
    const notes = body.notes ? String(body.notes).trim().slice(0, 1000) : null;
    const completedBy = body.completed_by ? String(body.completed_by).trim().slice(0, 200) : null;

    // Insert completion log (immutable)
    const { data: completion, error: insertErr } = await sb
      .from('ppm_completions')
      .insert({
        society_id:   SOCIETY_ID,
        schedule_id:  scheduleId,
        completed_on: completedOn,
        completed_by: completedBy,
        notes,
        cost:         cost && cost > 0 ? cost : null,
        next_due_date: nextDue,
        created_by:   user.id,
      })
      .select('id, completed_on, next_due_date')
      .single();

    if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });

    // Advance the schedule's next_due_date and last_completed_at
    const { error: updateErr } = await sb
      .from('ppm_schedules')
      .update({ last_completed_at: completedOn, next_due_date: nextDue })
      .eq('id', scheduleId)
      .eq('society_id', SOCIETY_ID);

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    await writeAuditLog(sb, {
      societyId:    SOCIETY_ID,
      actorId:      user.id,
      action:       'UPDATE',
      resourceType: 'ppm_schedules',
      resourceId:   scheduleId,
      newValues:    { completed_on: completedOn, next_due_date: nextDue, cost },
      ipAddress:    extractClientIP(request),
    });

    return Response.json({ completion_id: completion!.id, next_due_date: nextDue });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
