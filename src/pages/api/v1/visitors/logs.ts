export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const visitorType = url.searchParams.get('visitor_type')?.trim() ?? '';
    const gateId      = url.searchParams.get('gate_id')?.trim() ?? '';
    const dateFrom    = url.searchParams.get('date_from')?.trim() ?? '';
    const dateTo      = url.searchParams.get('date_to')?.trim() ?? '';
    const limit       = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 500);

    let query = sb
      .from('visitor_logs')
      .select(`id, visitor_name, host_unit_id, entry_type, visitor_type, gate_id,
               entry_time, exit_time, vehicle_number, logged_by, created_at,
               units(unit_number), gates(name, gate_code)`)
      .eq('society_id', SOCIETY_ID)
      .order('entry_time', { ascending: false })
      .limit(limit);

    if (user.role === 'member') {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      if (profile?.unit_id) query = query.eq('host_unit_id', profile.unit_id);
    }

    if (visitorType) query = query.eq('visitor_type', visitorType);
    if (gateId)      query = query.eq('gate_id', gateId);
    if (dateFrom)    query = query.gte('entry_time', `${dateFrom}T00:00:00`);
    if (dateTo)      query = query.lte('entry_time', `${dateTo}T23:59:59`);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['security_guard','executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only security staff can log entries' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
    }

    const body = await request.json() as {
      visitor_name?: string; host_unit_id?: string; entry_type?: string;
      visitor_type?: string; gate_id?: string; vehicle_number?: string; pre_approval_id?: string;
    };

    if (!body.visitor_name || !body.host_unit_id || !body.entry_type) {
      return new Response(JSON.stringify({ error: 'visitor_name, host_unit_id and entry_type are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('visitor_logs')
      .insert({
        society_id:      SOCIETY_ID,
        pre_approval_id: body.pre_approval_id ?? null,
        visitor_name:    sanitizePlainText(body.visitor_name),
        host_unit_id:    body.host_unit_id,
        entry_type:      body.entry_type,
        visitor_type:    body.visitor_type ?? null,
        gate_id:         body.gate_id ?? null,
        entry_time:      new Date().toISOString(),
        vehicle_number:  body.vehicle_number ? sanitizePlainText(body.vehicle_number) : null,
        logged_by:       user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
