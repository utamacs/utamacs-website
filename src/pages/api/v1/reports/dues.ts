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

    const wing     = url.searchParams.get('wing')    ?? '';
    const overdue  = url.searchParams.get('overdue') ?? '';
    const period   = url.searchParams.get('period')  ?? '';
    const format   = url.searchParams.get('format')  ?? 'json';

    const sb = getSupabaseServiceClient();
    let q = sb
      .from('maintenance_dues')
      .select(`
        id, base_amount, penalty_amount, total_amount, due_date, status, created_at,
        billing_periods(name),
        units(unit_number, block),
        profiles(full_name)
      `)
      .eq('society_id', SOCIETY_ID)
      .in('status', ['pending', 'overdue'])
      .order('due_date', { ascending: true });

    if (period) q = (q as any).eq('billing_period_id', period);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const now = Date.now();
    let rows = (data ?? []).map((r: any) => ({
      ...r,
      overdue_days: r.due_date ? Math.max(0, Math.floor((now - new Date(r.due_date).getTime()) / 86400000)) : 0,
    }));

    if (wing)   rows = rows.filter((r: any) => r.units?.block === wing);
    if (overdue === '30')  rows = rows.filter((r: any) => r.overdue_days > 30);
    if (overdue === '60')  rows = rows.filter((r: any) => r.overdue_days > 60);
    if (overdue === '90')  rows = rows.filter((r: any) => r.overdue_days > 90);

    if (format === 'csv') {
      const header = csvRow(['Flat No.','Block','Owner Name','Billing Period','Due Date','Base Amount (₹)','Late Fee (₹)','Total Due (₹)','Overdue Days']);
      const lines = rows.map((r: any) => csvRow([
        r.units?.unit_number ?? '',
        r.units?.block ?? '',
        r.profiles?.full_name ?? '',
        r.billing_periods?.name ?? '',
        r.due_date ?? '',
        r.base_amount,
        r.penalty_amount ?? 0,
        r.total_amount,
        r.overdue_days,
      ]));
      const date = new Date().toISOString().slice(0, 10);
      return new Response([header, ...lines].join('\n'), {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename="pending-dues-${date}.csv"`,
        },
      });
    }

    const total = rows.reduce((s: number, r: any) => s + Number(r.total_amount ?? 0), 0);
    const avgDays = rows.length ? Math.round(rows.reduce((s: number, r: any) => s + r.overdue_days, 0) / rows.length) : 0;
    return Response.json({ rows, total: Math.round(total), count: rows.length, avg_overdue_days: avgDays });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
