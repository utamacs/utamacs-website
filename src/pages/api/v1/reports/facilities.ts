export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: any) {
  return user.isAdmin || ['executive','secretary','president'].includes(user.portalRole ?? '') || ['executive','admin'].includes(user.role ?? '');
}

function csvRow(fields: (string | number | null | undefined)[]) {
  return fields.map(f => {
    const s = String(f ?? '');
    return s.includes(',') || s.includes('"') ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',');
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const from     = url.searchParams.get('from')     ?? '';
    const to       = url.searchParams.get('to')       ?? '';
    const facility = url.searchParams.get('facility') ?? '';
    const format   = url.searchParams.get('format')   ?? 'json';

    const sb = getSupabaseServiceClient();
    let q = sb
      .from('bookings')
      .select(`
        id, status, start_time, end_time, total_amount, created_at,
        facilities(name),
        profiles(full_name),
        units(unit_number, block)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('start_time', { ascending: false });

    if (from)     q = (q as any).gte('start_time', from);
    if (to)       q = (q as any).lte('start_time', to + 'T23:59:59Z');
    if (facility) q = (q as any).eq('facility_id', facility);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    const rows = (data ?? []) as any[];

    if (format === 'csv') {
      const header = csvRow(['Facility','Date','Start','End','Member','Flat','Status','Amount (₹)']);
      const lines = rows.map(r => csvRow([
        r.facilities?.name ?? '',
        r.start_time ? new Date(r.start_time).toLocaleDateString('en-IN') : '',
        r.start_time ? new Date(r.start_time).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '',
        r.end_time   ? new Date(r.end_time).toLocaleTimeString('en-IN',   { hour: '2-digit', minute: '2-digit' }) : '',
        r.profiles?.full_name ?? '',
        `${r.units?.block ?? ''}${r.units?.unit_number ?? ''}`,
        r.status ?? '',
        r.total_amount ?? 0,
      ]));
      const date = new Date().toISOString().slice(0, 10);
      return new Response([header, ...lines].join('\n'), {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename="facility-utilisation-${date}.csv"`,
        },
      });
    }

    const byFacility = rows.reduce((acc: Record<string, number>, r: any) => {
      const name = r.facilities?.name ?? 'Unknown';
      acc[name] = (acc[name] ?? 0) + 1;
      return acc;
    }, {});
    const revenue = rows.reduce((s: number, r: any) => s + Number(r.total_amount ?? 0), 0);

    return Response.json({ rows, count: rows.length, by_facility: byFacility, total_revenue: Math.round(revenue) });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
