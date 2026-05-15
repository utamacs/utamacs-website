export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/**
 * GET /api/v1/finance/credits
 * Members see their own credits; exec/admin see all with member details.
 * Query: ?status=available|refunded|applied (optional filter)
 */
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isExec = user.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      ['executive', 'admin'].includes(user.role ?? '');

    const statusFilter = url.searchParams.get('status');
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('member_credits')
      .select(`
        id, amount, status, notes, refunded_at, created_at,
        source_payment, applied_to_dues,
        profiles!user_id(full_name, units(unit_number))
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (!isExec) {
      query = query.eq('user_id', user.id);
    }

    if (statusFilter && ['available', 'refunded', 'applied'].includes(statusFilter)) {
      query = query.eq('status', statusFilter);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Compute totals for convenience
    const available_total = (data ?? [])
      .filter((c: any) => c.status === 'available')
      .reduce((s: number, c: any) => s + Number(c.amount), 0);

    return Response.json({ credits: data ?? [], available_total });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
