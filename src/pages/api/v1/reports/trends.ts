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

// GET /api/v1/reports/trends
// Returns:
//   collection_rate_trend: per billing-period collection efficiency (% units fully paid)
//   monthly_pl: month-by-month income vs expenses
//   complaint_sla_trend: monthly % complaints resolved within SLA
//   occupancy: breakdown by type + block
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['ANALYTICS_TREND_MONTHS', 'COMPLAINT_SLA_HOURS']);
    const trendMonths = ruleInt(rules, 'ANALYTICS_TREND_MONTHS', 12);
    const slaHours    = ruleInt(rules, 'COMPLAINT_SLA_HOURS', 72);

    const since = new Date();
    since.setMonth(since.getMonth() - trendMonths);
    since.setDate(1);
    since.setHours(0, 0, 0, 0);
    const sinceStr = since.toISOString();

    // ── Collection rate per billing period ─────────────────────────────────
    const { data: duePeriods } = await sb
      .from('maintenance_dues')
      .select('status, total_amount, billing_period_id, billing_periods(name, due_date)')
      .eq('society_id', SOCIETY_ID)
      .gte('created_at', sinceStr)
      .order('billing_period_id');

    const periodMap: Record<string, {
      name: string; due_date: string;
      total: number; paid: number; partial: number; pending: number;
      total_amount: number; collected_amount: number;
    }> = {};

    for (const d of duePeriods ?? []) {
      const bp = d.billing_periods as any;
      const pid = d.billing_period_id as string;
      if (!pid) continue;
      if (!periodMap[pid]) {
        periodMap[pid] = {
          name: bp?.name ?? pid,
          due_date: bp?.due_date ?? '',
          total: 0, paid: 0, partial: 0, pending: 0,
          total_amount: 0, collected_amount: 0,
        };
      }
      const p = periodMap[pid];
      p.total++;
      p.total_amount += Number(d.total_amount ?? 0);
      if (d.status === 'paid')           { p.paid++;    p.collected_amount += Number(d.total_amount ?? 0); }
      else if (d.status === 'partially_paid') { p.partial++; }
      else                               { p.pending++; }
    }

    const collection_rate_trend = Object.values(periodMap)
      .sort((a, b) => a.due_date.localeCompare(b.due_date))
      .map(p => ({
        period:          p.name,
        due_date:        p.due_date,
        total_units:     p.total,
        paid_units:      p.paid,
        partial_units:   p.partial,
        pending_units:   p.pending,
        collection_rate: p.total > 0 ? Math.round((p.paid / p.total) * 100) : 0,
        total_demand:    Math.round(p.total_amount),
        total_collected: Math.round(p.collected_amount),
        efficiency:      p.total_amount > 0 ? Math.round((p.collected_amount / p.total_amount) * 100) : 0,
      }));

    // ── Monthly P&L ────────────────────────────────────────────────────────
    const [{ data: payments }, { data: expenses }] = await Promise.all([
      sb.from('payments')
        .select('amount, paid_at')
        .eq('society_id', SOCIETY_ID)
        .gte('paid_at', sinceStr),
      sb.from('expenses')
        .select('net_payable, amount, payment_date')
        .eq('society_id', SOCIETY_ID)
        .gte('payment_date', sinceStr.slice(0, 10)),
    ]);

    const plByMonth: Record<string, { month: string; income: number; expenses: number }> = {};
    for (const p of payments ?? []) {
      const key = (p.paid_at as string).slice(0, 7); // YYYY-MM
      if (!plByMonth[key]) plByMonth[key] = { month: key, income: 0, expenses: 0 };
      plByMonth[key].income += Number(p.amount ?? 0);
    }
    for (const e of expenses ?? []) {
      const key = (e.payment_date as string).slice(0, 7);
      if (!plByMonth[key]) plByMonth[key] = { month: key, income: 0, expenses: 0 };
      plByMonth[key].expenses += Number(e.net_payable ?? e.amount ?? 0);
    }

    const monthly_pl = Object.values(plByMonth)
      .sort((a, b) => a.month.localeCompare(b.month))
      .map(m => ({
        month:    m.month,
        income:   Math.round(m.income),
        expenses: Math.round(m.expenses),
        net:      Math.round(m.income - m.expenses),
      }));

    // ── Complaint SLA compliance trend ────────────────────────────────────
    const { data: complaints } = await sb
      .from('complaints')
      .select('status, created_at, resolved_at, updated_at')
      .eq('society_id', SOCIETY_ID)
      .gte('created_at', sinceStr);

    const slaByMonth: Record<string, { total: number; within_sla: number }> = {};
    for (const c of complaints ?? []) {
      const key = (c.created_at as string).slice(0, 7);
      if (!slaByMonth[key]) slaByMonth[key] = { total: 0, within_sla: 0 };
      slaByMonth[key].total++;
      if (c.resolved_at) {
        const hrs = (new Date(c.resolved_at).getTime() - new Date(c.created_at).getTime()) / 3_600_000;
        if (hrs <= slaHours) slaByMonth[key].within_sla++;
      }
    }

    const complaint_sla_trend = Object.entries(slaByMonth)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([month, v]) => ({
        month,
        total:       v.total,
        within_sla:  v.within_sla,
        sla_rate:    v.total > 0 ? Math.round((v.within_sla / v.total) * 100) : 0,
      }));

    // ── Occupancy breakdown ────────────────────────────────────────────────
    const [{ data: allUnits }, { data: occupiedProfiles }] = await Promise.all([
      sb.from('units').select('id, block, floor').eq('society_id', SOCIETY_ID),
      sb.from('profiles')
        .select('unit_id, residency_type')
        .eq('society_id', SOCIETY_ID)
        .eq('is_active', true)
        .not('unit_id', 'is', null),
    ]);

    const occupiedUnitIds = new Set((occupiedProfiles ?? []).map((p: any) => p.unit_id));
    const resTypeByUnit: Record<string, string> = {};
    for (const p of occupiedProfiles ?? []) {
      resTypeByUnit[(p as any).unit_id] = (p as any).residency_type ?? 'owner';
    }

    const blockOccupancy: Record<string, { total: number; owner: number; tenant: number; vacant: number }> = {};
    let totalUnits = 0; let ownerUnits = 0; let tenantUnits = 0; let vacantUnits = 0;

    for (const u of allUnits ?? []) {
      const block = (u as any).block ?? 'Other';
      if (!blockOccupancy[block]) blockOccupancy[block] = { total: 0, owner: 0, tenant: 0, vacant: 0 };
      blockOccupancy[block].total++;
      totalUnits++;
      if (!occupiedUnitIds.has(u.id)) {
        blockOccupancy[block].vacant++; vacantUnits++;
      } else {
        const rt = resTypeByUnit[u.id] ?? 'owner';
        if (rt === 'tenant') { blockOccupancy[block].tenant++; tenantUnits++; }
        else                 { blockOccupancy[block].owner++;  ownerUnits++; }
      }
    }

    const occupancy = {
      total:   totalUnits,
      owner:   ownerUnits,
      tenant:  tenantUnits,
      vacant:  vacantUnits,
      occupancy_rate: totalUnits > 0 ? Math.round(((ownerUnits + tenantUnits) / totalUnits) * 100) : 0,
      by_block: Object.entries(blockOccupancy)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([block, v]) => ({ block, ...v })),
    };

    return Response.json({
      collection_rate_trend,
      monthly_pl,
      complaint_sla_trend,
      occupancy,
      meta: { trend_months: trendMonths, sla_hours: slaHours, as_of: new Date().toISOString() },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
