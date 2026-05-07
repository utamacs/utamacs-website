export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GSTR-3B is due 20th of the following month; GSTR-1 quarterly is due 13th of month after quarter end
function getFilingDeadlines(fy: number) {
  const deadlines: Array<{ name: string; due_date: string; period: string; filed: boolean }> = [];
  const quarters = [
    { name: 'Q1 (Apr–Jun)', month_end: `${fy}-06-30`, gstr1_due: `${fy}-07-13`, gstr3b_due: `${fy}-07-20` },
    { name: 'Q2 (Jul–Sep)', month_end: `${fy}-09-30`, gstr1_due: `${fy}-10-13`, gstr3b_due: `${fy}-10-20` },
    { name: 'Q3 (Oct–Dec)', month_end: `${fy}-12-31`, gstr1_due: `${fy + 1}-01-13`, gstr3b_due: `${fy + 1}-01-20` },
    { name: 'Q4 (Jan–Mar)', month_end: `${fy + 1}-03-31`, gstr1_due: `${fy + 1}-04-13`, gstr3b_due: `${fy + 1}-04-20` },
  ];
  const today = new Date().toISOString().slice(0, 10);
  for (const q of quarters) {
    if (q.month_end > today && q.gstr1_due > today) continue; // future quarter, skip if not yet due
    deadlines.push({ name: `GSTR-1 ${q.name}`, due_date: q.gstr1_due, period: q.name, filed: false });
    deadlines.push({ name: `GSTR-3B ${q.name}`, due_date: q.gstr3b_due, period: q.name, filed: false });
  }
  return deadlines.sort((a, b) => a.due_date.localeCompare(b.due_date));
}

// GET /api/v1/finance/gst-report?fy=2025
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const fy = parseInt(url.searchParams.get('fy') ?? String(new Date().getMonth() >= 3 ? new Date().getFullYear() : new Date().getFullYear() - 1), 10);
    const fromDate = `${fy}-04-01`;
    const toDate   = `${fy + 1}-03-31`;

    const sb = getSupabaseServiceClient();

    // GST collected on maintenance dues (paid)
    const [duesRes, expensesRes] = await Promise.all([
      sb.from('payments')
        .select('amount, paid_at, maintenance_dues!inner(gst_amount, base_amount)')
        .eq('society_id', SOCIETY_ID)
        .gte('paid_at', fromDate)
        .lte('paid_at', toDate + 'T23:59:59'),
      sb.from('expenses')
        .select('payment_date, gst_amount, amount')
        .eq('society_id', SOCIETY_ID)
        .gte('payment_date', fromDate)
        .lte('payment_date', toDate),
    ]);

    if (duesRes.error) throw Object.assign(new Error(duesRes.error.message), { status: 500 });
    if (expensesRes.error) throw Object.assign(new Error(expensesRes.error.message), { status: 500 });

    // Quarterly GST output (collected on dues)
    const quarterlyOutput: Record<string, { gst_collected: number; base_amount: number }> = {
      'Q1': { gst_collected: 0, base_amount: 0 },
      'Q2': { gst_collected: 0, base_amount: 0 },
      'Q3': { gst_collected: 0, base_amount: 0 },
      'Q4': { gst_collected: 0, base_amount: 0 },
    };

    for (const p of duesRes.data ?? []) {
      const month = new Date((p as any).paid_at).getMonth() + 1; // 1-12
      const q = month >= 4 && month <= 6 ? 'Q1'
             : month >= 7 && month <= 9 ? 'Q2'
             : month >= 10 && month <= 12 ? 'Q3'
             : 'Q4';
      const gstAmt = Number((p as any).maintenance_dues?.gst_amount ?? 0);
      const baseAmt = Number((p as any).maintenance_dues?.base_amount ?? 0);
      quarterlyOutput[q].gst_collected += gstAmt;
      quarterlyOutput[q].base_amount += baseAmt;
    }

    // Quarterly GST input (paid on expenses — claimable ITC)
    const quarterlyInput: Record<string, { gst_paid: number }> = {
      'Q1': { gst_paid: 0 }, 'Q2': { gst_paid: 0 }, 'Q3': { gst_paid: 0 }, 'Q4': { gst_paid: 0 },
    };

    for (const e of expensesRes.data ?? []) {
      if (!e.gst_amount || Number(e.gst_amount) <= 0) continue;
      const month = new Date((e as any).payment_date).getMonth() + 1;
      const q = month >= 4 && month <= 6 ? 'Q1'
             : month >= 7 && month <= 9 ? 'Q2'
             : month >= 10 && month <= 12 ? 'Q3'
             : 'Q4';
      quarterlyInput[q].gst_paid += Number(e.gst_amount ?? 0);
    }

    const totalGstCollected = Object.values(quarterlyOutput).reduce((s, q) => s + q.gst_collected, 0);
    const totalGstPaid      = Object.values(quarterlyInput).reduce((s, q) => s + q.gst_paid, 0);
    const netGstLiability   = totalGstCollected - totalGstPaid;

    const quarters = ['Q1', 'Q2', 'Q3', 'Q4'].map(q => ({
      quarter: q,
      gst_output: quarterlyOutput[q].gst_collected,
      base_amount: quarterlyOutput[q].base_amount,
      gst_input: quarterlyInput[q].gst_paid,
      net_liability: quarterlyOutput[q].gst_collected - quarterlyInput[q].gst_paid,
    }));

    const deadlines = getFilingDeadlines(fy);
    const today = new Date().toISOString().slice(0, 10);
    const upcomingDeadlines = deadlines
      .filter(d => d.due_date >= today)
      .map(d => ({
        ...d,
        days_until: Math.ceil((new Date(d.due_date).getTime() - Date.now()) / 86400000),
      }))
      .slice(0, 4);

    return Response.json({
      fy,
      summary: {
        total_gst_collected: totalGstCollected,
        total_itc_claimed: totalGstPaid,
        net_gst_liability: netGstLiability,
        gst_applicable_payments: (duesRes.data ?? []).filter((p: any) => Number(p.maintenance_dues?.gst_amount ?? 0) > 0).length,
      },
      quarterly_breakdown: quarters,
      upcoming_deadlines: upcomingDeadlines,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
