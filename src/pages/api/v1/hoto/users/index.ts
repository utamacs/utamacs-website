export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list members with portal_role, committee_title, and unit info.
// Query params:
//   q     - name search (ilike)
//   role  - filter by portal_role
//   limit - default 50, max 200
// Auth: users.view_directory feature required
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) {
      return Response.json(
        { error: 'UNAUTHORIZED', message: 'Authentication required' },
        { status: 401 },
      );
    }

    requireFeature(user, 'users.view_directory');

    const q = url.searchParams.get('q')?.trim() ?? '';
    const roleFilter = url.searchParams.get('role')?.trim() ?? '';
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 200);

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('profiles')
      .select(`
        id, full_name, portal_role, committee_title, is_admin,
        residency_type, is_active, move_in_date,
        units(unit_number, block)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('full_name')
      .limit(limit);

    if (q) query = query.ilike('full_name', `%${q}%`);
    if (roleFilter) query = query.eq('portal_role', roleFilter);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // executive+ roles can see move_in_date
    const canSeeMoveIn =
      user.portalRole === 'executive' ||
      user.portalRole === 'secretary' ||
      user.portalRole === 'president' ||
      user.isAdmin;

    const members = (data ?? []).map((m: any) => ({
      id: m.id,
      full_name: m.full_name,
      unit_number: m.units?.unit_number ?? null,
      block: m.units?.block ?? null,
      portal_role: m.portal_role ?? 'member',
      committee_title: m.committee_title ?? null,
      is_admin: m.is_admin ?? false,
      residency_type: m.residency_type ?? null,
      is_active: m.is_active ?? true,
      ...(canSeeMoveIn ? { move_in_date: m.move_in_date ?? null } : {}),
    }));

    return Response.json(members);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
