import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — TDS summary: payments with TDS + expenses with TDS, grouped by vendor/member, filterable by FY
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const fy = url.searchParams.get('fy'); // e.g. "2025" = FY2025-26 = Apr 2025 – Mar 2026
    const sb = getSupabaseServiceClient();

    let fromDate: string | null = null;
    let toDate: string | null = null;
    if (fy) {
      const y = parseInt(fy, 10);
      fromDate = `${y}-04-01`;
      toDate = `${y + 1}-03-31`;
    }

    // TDS on maintenance payments (member payments with TDS)
    let paymentsQuery = sb
      .from('payments')
      .select(`
        id, amount, tds_deducted, paid_at, payment_mode, receipt_number,
        maintenance_dues(
          units(unit_number, block),
          profiles(full_name)
        )
      `)
      .eq('society_id', SOCIETY_ID)
      .gt('tds_deducted', 0)
      .order('paid_at', { ascending: false });

    if (fromDate) paymentsQuery = paymentsQuery.gte('paid_at', fromDate);
    if (toDate) paymentsQuery = paymentsQuery.lte('paid_at', toDate + 'T23:59:59');

    // TDS on vendor expenses
    let expensesQuery = sb
      .from('expenses')
      .select(`
        id, amount, tds_deducted, payment_date, bill_number,
        vendors(name, pan, gstin),
        expense_categories(name)
      `)
      .eq('society_id', SOCIETY_ID)
      .gt('tds_deducted', 0)
      .order('payment_date', { ascending: false });

    if (fromDate) expensesQuery = expensesQuery.gte('payment_date', fromDate);
    if (toDate) expensesQuery = expensesQuery.lte('payment_date', toDate);

    const [{ data: payments, error: pErr }, { data: expenses, error: eErr }] = await Promise.all([
      paymentsQuery,
      expensesQuery,
    ]);

    if (pErr) throw Object.assign(new Error(pErr.message), { status: 500 });
    if (eErr) throw Object.assign(new Error(eErr.message), { status: 500 });

    const totalTdsOnPayments = (payments ?? []).reduce((sum, p) => sum + Number((p as any).tds_deducted ?? 0), 0);
    const totalTdsOnExpenses = (expenses ?? []).reduce((sum, e) => sum + Number((e as any).tds_deducted ?? 0), 0);

    // Aggregate vendor TDS for Form 26Q summary
    const vendorTdsSummary: Record<string, { vendor_name: string; pan: string | null; total_expense: number; total_tds: number; entries: number }> = {};
    for (const exp of expenses ?? []) {
      const e = exp as any;
      const vendorId = e.vendor_id || e.vendors?.name || 'unknown';
      if (!vendorTdsSummary[vendorId]) {
        vendorTdsSummary[vendorId] = {
          vendor_name: e.vendors?.name ?? 'Unknown',
          pan: e.vendors?.pan ?? null,
          total_expense: 0, total_tds: 0, entries: 0,
        };
      }
      vendorTdsSummary[vendorId].total_expense += Number(e.amount ?? 0);
      vendorTdsSummary[vendorId].total_tds += Number(e.tds_deducted ?? 0);
      vendorTdsSummary[vendorId].entries++;
    }

    // Flag vendors missing PAN (cannot issue Form 16A without PAN)
    const missingPanVendors = Object.values(vendorTdsSummary).filter(v => !v.pan && v.total_tds > 0);

    return new Response(JSON.stringify({
      summary: {
        total_tds_on_payments: totalTdsOnPayments,
        total_tds_on_expenses: totalTdsOnExpenses,
        total_tds: totalTdsOnPayments + totalTdsOnExpenses,
        fy: fy ?? 'all',
        missing_pan_vendor_count: missingPanVendors.length,
      },
      vendor_tds_summary: Object.values(vendorTdsSummary),
      missing_pan_vendors: missingPanVendors,
      payments_with_tds: payments ?? [],
      expenses_with_tds: expenses ?? [],
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
