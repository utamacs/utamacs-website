export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_FREQUENCIES = ['daily','weekly','fortnightly','monthly','quarterly','half_yearly','annual'] as const;
const FREQUENCY_DAYS: Record<string, number> = {
  daily: 1, weekly: 7, fortnightly: 14, monthly: 30,
  quarterly: 90, half_yearly: 180, annual: 365,
};

function addDays(date: string, days: number): string {
  const d = new Date(date + 'T00:00:00');
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function requireExec(user: { isAdmin: boolean; portalRole?: string | null }) {
  return user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
}

// GET /api/v1/admin/ppm?status=upcoming|overdue|all&asset_id=
// Returns schedules with their last completion and overdue status.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['PPM_OVERDUE_ALERT_DAYS']);
    const alertDays = ruleInt(rules, 'PPM_OVERDUE_ALERT_DAYS', 7);

    const status  = url.searchParams.get('status') ?? 'all';
    const assetId = url.searchParams.get('asset_id')?.trim() ?? '';

    const today    = new Date().toISOString().slice(0, 10);
    const alertCut = addDays(today, alertDays);

    let q = sb
      .from('ppm_schedules')
      .select(`
        id, title, description, frequency, frequency_days, responsible_role,
        last_completed_at, next_due_date, is_active, notes, created_at,
        asset_id,
        infrastructure_assets ( id, name, asset_code, category, status )
      `)
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('next_due_date', { ascending: true, nullsFirst: false });

    if (assetId && UUID_RE.test(assetId)) q = (q as any).eq('asset_id', assetId);
    if (status === 'overdue')  q = (q as any).lt('next_due_date', today).not('next_due_date', 'is', null);
    if (status === 'upcoming') q = (q as any).lte('next_due_date', alertCut).gte('next_due_date', today);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const schedules = (data ?? []).map((s: any) => ({
      ...s,
      is_overdue:  s.next_due_date ? s.next_due_date < today : false,
      is_upcoming: s.next_due_date ? s.next_due_date >= today && s.next_due_date <= alertCut : false,
      days_until:  s.next_due_date
        ? Math.floor((new Date(s.next_due_date + 'T00:00:00').getTime() - Date.now()) / 86_400_000)
        : null,
    }));

    const overdue_count  = schedules.filter((s: any) => s.is_overdue).length;
    const upcoming_count = schedules.filter((s: any) => s.is_upcoming).length;

    return Response.json({ schedules, overdue_count, upcoming_count, alert_days: alertDays });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/admin/ppm — create a new PPM schedule
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const title     = String(body.title ?? '').trim();
    const frequency = String(body.frequency ?? 'monthly');
    const assetId   = body.asset_id ? String(body.asset_id) : null;
    const startDate = body.start_date ? String(body.start_date) : new Date().toISOString().slice(0, 10);

    if (!title)  return Response.json({ error: 'VALIDATION', message: 'title is required' }, { status: 400 });
    if (!VALID_FREQUENCIES.includes(frequency as any))
      return Response.json({ error: 'VALIDATION', message: 'Invalid frequency' }, { status: 400 });
    if (assetId && !UUID_RE.test(assetId))
      return Response.json({ error: 'VALIDATION', message: 'Invalid asset_id' }, { status: 400 });

    const freqDays  = Number(body.frequency_days) > 0 ? Number(body.frequency_days) : FREQUENCY_DAYS[frequency] ?? 30;
    const nextDue   = addDays(startDate, freqDays);

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('ppm_schedules')
      .insert({
        society_id:       SOCIETY_ID,
        asset_id:         assetId,
        title:            title.slice(0, 200),
        description:      body.description ? String(body.description).trim().slice(0, 1000) : null,
        frequency,
        frequency_days:   freqDays,
        responsible_role: body.responsible_role ? String(body.responsible_role).slice(0, 100) : null,
        next_due_date:    nextDue,
        notes:            body.notes ? String(body.notes).trim().slice(0, 1000) : null,
        created_by:       user.id,
      })
      .select('id, title, frequency, next_due_date')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       'CREATE',
      resourceType: 'ppm_schedules',
      resourceId:   data!.id,
      newValues:    { title, frequency, asset_id: assetId },
      ip:           extractClientIP(request),
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
