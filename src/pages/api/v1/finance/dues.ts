export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('maintenance_dues')
      .select(`
        id, unit_id, user_id, billing_period_id, base_amount, penalty_amount,
        gst_amount, total_amount, status, due_date, paid_at,
        billing_periods(name, start_date, end_date),
        units(unit_number)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('due_date', { ascending: false });

    if (user.role === 'member') {
      query = query.eq('user_id', user.id);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

/**
 * POST — create a billing period and bulk-generate dues for all active units.
 * Body: { name, start_date, end_date, due_date, base_amount, gst_rate?, penalty_amount? }
 * Idempotent per billing_period: will not create duplicate dues if period already has dues.
 */
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      name?: string; start_date?: string; end_date?: string;
      due_date?: string; base_amount?: number;
      gst_rate?: number; penalty_amount?: number;
    };

    if (!body.name || !body.start_date || !body.end_date || !body.due_date || body.base_amount == null) {
      return new Response(JSON.stringify({ error: 'name, start_date, end_date, due_date, base_amount are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Create billing period
    const { data: period, error: periodErr } = await sb
      .from('billing_periods')
      .insert({
        society_id: SOCIETY_ID,
        name: body.name,
        start_date: body.start_date,
        end_date: body.end_date,
        due_date: body.due_date,
        base_amount: body.base_amount,
        is_active: true,
      })
      .select()
      .single();

    if (periodErr) throw Object.assign(new Error(periodErr.message), { status: 500 });

    // Fetch all active units + their primary resident (owner > tenant)
    const { data: units, error: unitErr } = await sb
      .from('units')
      .select('id, unit_number')
      .eq('society_id', SOCIETY_ID)
      .eq('is_vacant', false);

    if (unitErr) throw Object.assign(new Error(unitErr.message), { status: 500 });

    // For each unit, find the primary profile
    const { data: profiles } = await sb
      .from('profiles')
      .select('id, unit_id, residency_type')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('residency_type', { ascending: true }); // 'owner' sorts before 'tenant'

    const unitToUser: Record<string, string> = {};
    for (const p of profiles ?? []) {
      if (!unitToUser[p.unit_id]) unitToUser[p.unit_id] = p.id;
    }

    const gstRate = body.gst_rate ?? 0;
    const gstAmount = Math.round(body.base_amount * (gstRate / 100) * 100) / 100;
    const penaltyAmount = body.penalty_amount ?? 0;

    const dueRecords = (units ?? [])
      .filter((u: any) => unitToUser[u.id])
      .map((u: any) => ({
        society_id: SOCIETY_ID,
        unit_id: u.id,
        user_id: unitToUser[u.id],
        billing_period_id: period.id,
        base_amount: body.base_amount,
        gst_amount: gstAmount,
        penalty_amount: penaltyAmount,
        due_date: body.due_date,
        status: 'pending',
      }));

    if (dueRecords.length === 0) {
      return new Response(JSON.stringify({ period, dues_created: 0, warning: 'No active units with residents found' }), {
        status: 201, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { error: insertErr } = await sb.from('maintenance_dues').insert(dueRecords);
    if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'billing_periods', resourceId: period.id,
      ip: extractClientIP(request),
      newValues: { name: body.name, dues_created: dueRecords.length, base_amount: body.base_amount },
    });

    return new Response(JSON.stringify({ period, dues_created: dueRecords.length }), {
      status: 201, headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
