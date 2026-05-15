export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/visitors/frequent
// Returns the current user's most frequently pre-approved visitors (top N by pass count).
// Aggregated from visitor_pre_approvals — no new table needed.
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['VISITOR_FREQUENT_TOP_N']);
    const topN = ruleInt(rules, 'VISITOR_FREQUENT_TOP_N', 10);

    // Aggregate from the last 12 months to avoid stale names
    const since = new Date(Date.now() - 365 * 86_400_000).toISOString();

    const { data, error } = await sb
      .from('visitor_pre_approvals')
      .select('visitor_name, visitor_type, vehicle_number, host_unit_id')
      .eq('society_id', SOCIETY_ID)
      .eq('host_user_id', user.id)
      .gte('created_at', since)
      .order('created_at', { ascending: false });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Group by visitor_name (case-insensitive), keep latest metadata
    const map = new Map<string, {
      visitor_name: string;
      visitor_type: string | null;
      vehicle_number: string | null;
      count: number;
    }>();

    for (const row of data ?? []) {
      const key = (row.visitor_name as string).trim().toLowerCase();
      if (map.has(key)) {
        map.get(key)!.count++;
      } else {
        map.set(key, {
          visitor_name:   (row.visitor_name as string).trim(),
          visitor_type:   row.visitor_type as string | null,
          vehicle_number: row.vehicle_number as string | null,
          count:          1,
        });
      }
    }

    const frequent = [...map.values()]
      .sort((a, b) => b.count - a.count)
      .slice(0, topN);

    return Response.json({ frequent });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
