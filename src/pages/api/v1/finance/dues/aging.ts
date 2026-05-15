export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/finance/dues/aging — overdue aging report with bucket breakdown
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, [
      'DUES_AGING_BUCKET_1_DAYS',
      'DUES_AGING_BUCKET_2_DAYS',
      'DUES_AGING_BUCKET_3_DAYS',
    ]);
    const b1 = ruleInt(rules, 'DUES_AGING_BUCKET_1_DAYS', 30);
    const b2 = ruleInt(rules, 'DUES_AGING_BUCKET_2_DAYS', 60);
    const b3 = ruleInt(rules, 'DUES_AGING_BUCKET_3_DAYS', 90);

    const today = new Date();
    const todayStr = today.toISOString().split('T')[0];

    // Fetch all overdue dues with unit info
    const { data: dues, error } = await sb
      .from('maintenance_dues')
      .select(`
        id, unit_id, due_date, total_amount, amount_paid, status,
        reminder_sent_count, last_reminder_sent_at,
        units(unit_number, block),
        billing_periods(name)
      `)
      .eq('society_id', SOCIETY_ID)
      .in('status', ['pending', 'partially_paid'])
      .lt('due_date', todayStr)
      .order('due_date', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const rows = (dues ?? []).map(d => {
      const dueDate = new Date(d.due_date);
      const daysOverdue = Math.floor((today.getTime() - dueDate.getTime()) / 86_400_000);
      const outstanding = (d.total_amount ?? 0) - (d.amount_paid ?? 0);

      let bucket: '1_30' | '31_60' | '61_90' | '90_plus';
      if (daysOverdue <= b1)       bucket = '1_30';
      else if (daysOverdue <= b2)  bucket = '31_60';
      else if (daysOverdue <= b3)  bucket = '61_90';
      else                         bucket = '90_plus';

      return {
        id: d.id,
        unit_id: d.unit_id,
        unit_number: (d.units as any)?.unit_number ?? '',
        block: (d.units as any)?.block ?? '',
        billing_period: (d.billing_periods as any)?.name ?? '',
        due_date: d.due_date,
        total_amount: d.total_amount ?? 0,
        amount_paid: d.amount_paid ?? 0,
        outstanding,
        days_overdue: daysOverdue,
        bucket,
        reminder_sent_count: d.reminder_sent_count ?? 0,
        last_reminder_sent_at: d.last_reminder_sent_at ?? null,
      };
    });

    // Bucket summary
    const bucketTotals = {
      '1_30':    { count: 0, total: 0 },
      '31_60':   { count: 0, total: 0 },
      '61_90':   { count: 0, total: 0 },
      '90_plus': { count: 0, total: 0 },
    };
    for (const r of rows) {
      bucketTotals[r.bucket].count++;
      bucketTotals[r.bucket].total += r.outstanding;
    }

    const grandTotal = rows.reduce((s, r) => s + r.outstanding, 0);

    return Response.json({
      as_of: todayStr,
      bucket_labels: { b1, b2, b3 },
      summary: {
        total_overdue_units: rows.length,
        grand_total_outstanding: grandTotal,
        buckets: bucketTotals,
      },
      rows,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
