export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: { isAdmin: boolean; portalRole?: string | null; role?: string | null }) {
  return user.isAdmin || ['executive','secretary','president'].includes(user.portalRole ?? '') || ['executive','admin'].includes(user.role ?? '');
}

function csvRow(fields: (string | number | null | undefined)[]) {
  return fields.map(f => {
    const s = String(f ?? '');
    return s.includes(',') || s.includes('"') || s.includes('\n') ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',');
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const from   = url.searchParams.get('from')  ?? '';
    const to     = url.searchParams.get('to')    ?? '';
    const wing   = url.searchParams.get('wing')  ?? '';
    const mode   = url.searchParams.get('mode')  ?? '';
    const format = url.searchParams.get('format') ?? 'json';

    const sb = getSupabaseServiceClient();
    let q = sb
      .from('payments')
      .select(`
        id, amount, payment_mode, transaction_ref, receipt_number, paid_at,
        maintenance_dues(
          billing_periods(name),
          units(unit_number, block),
          profiles(full_name)
        )
      `)
      .eq('society_id', SOCIETY_ID)
      .order('paid_at', { ascending: false });

    if (from) q = (q as any).gte('paid_at', from);
    if (to)   q = (q as any).lte('paid_at', to + 'T23:59:59Z');
    if (mode) q = (q as any).eq('payment_mode', mode);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    let rows = (data ?? []) as any[];
    if (wing) rows = rows.filter(r => r.maintenance_dues?.units?.block === wing);

    if (format === 'csv') {
      const header = csvRow(['Date','Receipt No.','Flat No.','Block','Member Name','Mode','Reference','Amount (₹)','Billing Period']);
      const lines = rows.map(r => csvRow([
        r.paid_at ? new Date(r.paid_at).toLocaleDateString('en-IN') : '',
        r.receipt_number ?? '',
        r.maintenance_dues?.units?.unit_number ?? '',
        r.maintenance_dues?.units?.block ?? '',
        r.maintenance_dues?.profiles?.full_name ?? '',
        r.payment_mode ?? '',
        r.transaction_ref ?? '',
        r.amount,
        r.maintenance_dues?.billing_periods?.name ?? '',
      ]));
      const date = new Date().toISOString().slice(0, 10);
      return new Response([header, ...lines].join('\n'), {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename="collection-report-${date}.csv"`,
        },
      });
    }

    const total = rows.reduce((s, r) => s + Number(r.amount ?? 0), 0);
    return Response.json({ rows, total: Math.round(total), count: rows.length });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
