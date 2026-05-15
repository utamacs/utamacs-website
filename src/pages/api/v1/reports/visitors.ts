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

    const from   = url.searchParams.get('from')   ?? new Date(Date.now() - 30*86400000).toISOString().slice(0,10);
    const to     = url.searchParams.get('to')     ?? new Date().toISOString().slice(0,10);
    const type   = url.searchParams.get('type')   ?? '';
    const format = url.searchParams.get('format') ?? 'json';

    const sb = getSupabaseServiceClient();
    let q = sb
      .from('visitor_logs')
      .select('id, visitor_name, entry_type, entry_time, exit_time, purpose, host_unit_id, units(unit_number, block)')
      .eq('society_id', SOCIETY_ID)
      .gte('entry_time', from)
      .lte('entry_time', to + 'T23:59:59Z')
      .order('entry_time', { ascending: false });

    if (type) q = (q as any).eq('entry_type', type);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    const rows = data ?? [];

    if (format === 'csv') {
      const header = csvRow(['Date','Time','Visitor Name','Type','Purpose','Host Flat','Block','Exit Time']);
      const lines = (rows as any[]).map(r => csvRow([
        r.entry_time ? new Date(r.entry_time).toLocaleDateString('en-IN') : '',
        r.entry_time ? new Date(r.entry_time).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '',
        r.visitor_name ?? '',
        r.entry_type ?? '',
        r.purpose ?? '',
        r.units?.unit_number ?? '',
        r.units?.block ?? '',
        r.exit_time ? new Date(r.exit_time).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '',
      ]));
      const date = new Date().toISOString().slice(0, 10);
      return new Response([header, ...lines].join('\n'), {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename="visitor-log-${date}.csv"`,
        },
      });
    }

    const byType = (rows as any[]).reduce((acc: Record<string,number>, r: any) => {
      acc[r.entry_type ?? 'unknown'] = (acc[r.entry_type ?? 'unknown'] ?? 0) + 1;
      return acc;
    }, {});

    return Response.json({ rows, count: rows.length, by_type: byType });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
