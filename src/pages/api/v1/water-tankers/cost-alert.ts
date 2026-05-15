export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/water-tankers/cost-alert
// Returns active alerts:
//   - rate_exceeded: true if the most recent delivery ₹/kL > WATER_TANKER_MAX_COST_PER_KL
//   - no_delivery: true if last delivery was more than WATER_TANKER_NO_DELIVERY_ALERT_DAYS ago
// Any authenticated user can call (visible on the portal page).
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, [
      'WATER_TANKER_MAX_COST_PER_KL',
      'WATER_TANKER_NO_DELIVERY_ALERT_DAYS',
    ]);
    const maxCostPerKl  = ruleInt(rules, 'WATER_TANKER_MAX_COST_PER_KL', 300);
    const alertDays     = ruleInt(rules, 'WATER_TANKER_NO_DELIVERY_ALERT_DAYS', 5);

    const { data: latest } = await sb
      .from('water_tankers')
      .select('delivery_date, cost_per_kl, total_cost, total_kl, tanker_capacity_kl, tanker_count, supplier_name')
      .eq('society_id', SOCIETY_ID)
      .order('delivery_date', { ascending: false })
      .limit(1)
      .single();

    const alerts: {
      type: 'rate_exceeded' | 'no_delivery';
      message: string;
      detail: string;
    }[] = [];

    if (!latest) {
      // No deliveries ever logged
      alerts.push({
        type:    'no_delivery',
        message: 'No tanker deliveries logged yet.',
        detail:  'Log the first delivery to start tracking water management.',
      });
    } else {
      // Check no-delivery alert
      const lastDate  = new Date(latest.delivery_date + 'T00:00:00').getTime();
      const daysSince = Math.floor((Date.now() - lastDate) / 86_400_000);
      if (daysSince > alertDays) {
        alerts.push({
          type:    'no_delivery',
          message: `No tanker delivery logged for ${daysSince} day${daysSince !== 1 ? 's' : ''}.`,
          detail:  `Last delivery: ${latest.delivery_date} from ${latest.supplier_name ?? 'unknown supplier'}. Alert threshold: ${alertDays} days.`,
        });
      }

      // Check rate exceeded
      const totalKl   = latest.total_kl ?? (latest.tanker_capacity_kl ?? 0) * (latest.tanker_count ?? 1);
      const effectiveRate = latest.cost_per_kl
        ? Number(latest.cost_per_kl)
        : (latest.total_cost && totalKl > 0 ? Number(latest.total_cost) / totalKl : null);

      if (effectiveRate !== null && effectiveRate > maxCostPerKl) {
        alerts.push({
          type:    'rate_exceeded',
          message: `Last delivery rate ₹${Math.round(effectiveRate)}/KL exceeds threshold of ₹${maxCostPerKl}/KL.`,
          detail:  `Supplier: ${latest.supplier_name ?? '—'}, Date: ${latest.delivery_date}. Negotiate a better rate or flag for committee review.`,
        });
      }
    }

    return Response.json({
      alerts,
      config: { max_cost_per_kl: maxCostPerKl, alert_days: alertDays },
      last_delivery: latest ?? null,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
