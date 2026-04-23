export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const q = url.searchParams.get('q')?.trim() ?? '';
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);

    let query = sb
      .from('profiles')
      .select('id, full_name, residency_type, move_in_date, is_active, units(unit_number, block)')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('full_name')
      .limit(limit);

    if (q) query = query.ilike('full_name', `%${q}%`);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Fetch roles in one query for all returned members
    const memberIds = (data ?? []).map((m: any) => m.id);
    const { data: roles } = memberIds.length
      ? await sb.from('user_roles').select('user_id, role, expires_at').in('user_id', memberIds).eq('society_id', SOCIETY_ID)
      : { data: [] };
    const roleMap: Record<string, { role: string; expires_at: string | null }> = {};
    for (const r of roles ?? []) roleMap[r.user_id] = { role: r.role, expires_at: r.expires_at };

    const isPrivileged = ['executive', 'admin'].includes(user.role);
    const members = (data ?? []).map((m: any) => ({
      id: m.id,
      full_name: m.full_name,
      unit_number: m.units?.unit_number ?? null,
      block: m.units?.block ?? null,
      residency_type: m.residency_type,
      role: roleMap[m.id]?.role ?? 'member',
      ...(isPrivileged ? {
        move_in_date: m.move_in_date,
        role_expires_at: roleMap[m.id]?.expires_at ?? null,
      } : {}),
    }));

    return new Response(JSON.stringify(members), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
