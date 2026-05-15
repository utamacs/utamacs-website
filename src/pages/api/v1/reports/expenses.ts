export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: { isAdmin: boolean; portalRole?: string | null; role?: string | null }) {
  return user.isAdmin ||
    ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
    ['executive', 'admin'].includes(user.role ?? '');
}

function csvRow(fields: (string | number | null | undefined)[]) {
  return fields.map(f => {
    const s = String(f ?? '');
    return s.includes(',') || s.includes('"') ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',');
}

// GET /api/v1/reports/expenses?from=&to=&format=json|csv&vendor_id=
// Returns expense breakdown aggregated by category, with optional vendor filter.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const from      = url.searchParams.get('from') ?? '';
    const to        = url.searchParams.get('to')   ?? '';
    const vendorId  = url.searchParams.get('vendor_id') ?? '';
    const format    = url.searchParams.get('format') ?? 'json';

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['ANALYTICS_EXPENSE_TOP_N']);
    const topN  = ruleInt(rules, 'ANALYTICS_EXPENSE_TOP_N', 8);

    let q = sb
      .from('expenses')
      .select(`
        id, description, amount, net_payable, tds_deducted, gst_amount,
        payment_date, bill_number, approval_status,
        expense_categories(id, name),
        vendors(id, name)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('payment_date', { ascending: false });

    if (from) q = (q as any).gte('payment_date', from);
    if (to)   q = (q as any).lte('payment_date', to);
    if (vendorId) q = (q as any).eq('vendor_id', vendorId);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const rows = (data ?? []) as any[];

    // Category aggregation
    const catMap: Record<string, { name: string; total: number; count: number; tds: number }> = {};
    let grandTotal = 0;

    for (const e of rows) {
      const catId   = e.expense_categories?.id ?? 'uncategorised';
      const catName = e.expense_categories?.name ?? 'Uncategorised';
      const amt     = Number(e.net_payable ?? e.amount ?? 0);
      if (!catMap[catId]) catMap[catId] = { name: catName, total: 0, count: 0, tds: 0 };
      catMap[catId].total += amt;
      catMap[catId].count++;
      catMap[catId].tds   += Number(e.tds_deducted ?? 0);
      grandTotal += amt;
    }

    // Sort by total descending, group tail into "Other"
    const sorted = Object.values(catMap).sort((a, b) => b.total - a.total);
    const top    = sorted.slice(0, topN);
    const rest   = sorted.slice(topN);
    const other  = rest.reduce((s, c) => ({ name: 'Other', total: s.total + c.total, count: s.count + c.count, tds: s.tds + c.tds }), { name: 'Other', total: 0, count: 0, tds: 0 });
    const categories = rest.length > 0 ? [...top, other] : top;

    const categoryBreakdown = categories.map(c => ({
      name:       c.name,
      total:      Math.round(c.total),
      count:      c.count,
      tds:        Math.round(c.tds),
      percentage: grandTotal > 0 ? Math.round((c.total / grandTotal) * 100) : 0,
    }));

    if (format === 'csv') {
      const header = csvRow(['Date', 'Category', 'Vendor', 'Description', 'Amount (₹)', 'Net Payable (₹)', 'TDS (₹)', 'GST (₹)', 'Bill No.', 'Status']);
      const lines = rows.map((e: any) => csvRow([
        e.payment_date,
        e.expense_categories?.name ?? '',
        e.vendors?.name ?? '',
        e.description ?? '',
        e.amount,
        e.net_payable ?? e.amount,
        e.tds_deducted ?? 0,
        e.gst_amount ?? 0,
        e.bill_number ?? '',
        e.approval_status ?? '',
      ]));
      const date = new Date().toISOString().slice(0, 10);
      return new Response([header, ...lines].join('\n'), {
        headers: {
          'Content-Type':        'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename="expense-breakdown-${date}.csv"`,
        },
      });
    }

    return Response.json({
      grand_total:          Math.round(grandTotal),
      total_tds_deducted:   Math.round(rows.reduce((s: number, e: any) => s + Number(e.tds_deducted ?? 0), 0)),
      row_count:            rows.length,
      category_breakdown:   categoryBreakdown,
      rows,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
