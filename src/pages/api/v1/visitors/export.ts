export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const isPrivileged = ['executive', 'secretary', 'president', 'admin'].includes(user.portalRole ?? user.role);
    if (!isPrivileged) return new Response('Forbidden', { status: 403 });

    const sb = getSupabaseServiceClient();
    const visitorType = url.searchParams.get('visitor_type')?.trim() ?? '';
    const gateId      = url.searchParams.get('gate_id')?.trim() ?? '';
    const dateFrom    = url.searchParams.get('date_from')?.trim() ?? '';
    const dateTo      = url.searchParams.get('date_to')?.trim() ?? '';

    let query = sb
      .from('visitor_logs')
      .select(`visitor_name, host_unit_id, entry_type, visitor_type, gate_id,
               entry_time, exit_time, vehicle_number, created_at,
               units(unit_number, block), gates(name, gate_code)`)
      .eq('society_id', SOCIETY_ID)
      .order('entry_time', { ascending: false })
      .limit(5000);

    if (visitorType) query = query.eq('visitor_type', visitorType);
    if (gateId)      query = query.eq('gate_id', gateId);
    if (dateFrom)    query = query.gte('entry_time', `${dateFrom}T00:00:00`);
    if (dateTo)      query = query.lte('entry_time', `${dateTo}T23:59:59`);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const headers = ['Visitor Name', 'Unit', 'Block', 'Entry Type', 'Visitor Type', 'Gate', 'Entry Time', 'Exit Time', 'Vehicle', 'Duration (min)'];

    const escape = (v: string) => {
      const s = String(v ?? '');
      return s.includes(',') || s.includes('"') || s.includes('\n') ? `"${s.replace(/"/g, '""')}"` : s;
    };

    const rows = (data ?? []).map((l: any) => {
      const entry = new Date(l.entry_time);
      const exit  = l.exit_time ? new Date(l.exit_time) : null;
      const dur   = exit ? Math.round((exit.getTime() - entry.getTime()) / 60000).toString() : '';
      return [
        l.visitor_name ?? '',
        l.units?.unit_number ?? '',
        l.units?.block ?? '',
        (l.entry_type ?? '').replace(/_/g, ' '),
        (l.visitor_type ?? '').replace(/_/g, ' '),
        l.gates?.name ?? '',
        entry.toLocaleString('en-IN'),
        exit ? exit.toLocaleString('en-IN') : '',
        l.vehicle_number ?? '',
        dur,
      ];
    });

    const csv = [headers, ...rows].map(r => r.map(escape).join(',')).join('\r\n');
    const today = new Date().toISOString().slice(0, 10);

    return new Response(csv, {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="visitor-logs-${today}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
