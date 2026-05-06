export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list all rules, optionally filtered by category (auth: admin only)
// Query: category (PARAMETER|APPROVAL|ESCALATION|NOTIFICATION|VALIDATION)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin access required' }, { status: 403 });

    const url = new URL(request.url);
    const category = url.searchParams.get('category') ?? '';

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('rules')
      .select('*')
      .eq('society_id', SOCIETY_ID)
      .order('rule_category')
      .order('rule_code');

    if (category) query = query.eq('rule_category', category);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Group by category for convenient UI consumption
    const grouped: Record<string, unknown[]> = {};
    for (const rule of data ?? []) {
      const cat = (rule as any).rule_category;
      if (!grouped[cat]) grouped[cat] = [];
      grouped[cat].push(rule);
    }

    return Response.json({ rules: data ?? [], grouped });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
