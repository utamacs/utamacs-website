export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return new Response('Unauthorized', { status: 401 });
    requireFeature(user, 'users.view_directory');

    const sb = getSupabaseServiceClient();

    const q            = url.searchParams.get('q')?.trim() ?? '';
    const blockFilter  = url.searchParams.get('block')?.trim() ?? '';
    const occupancy    = url.searchParams.get('occupancy')?.trim() ?? '';
    const expiringDays = parseInt(url.searchParams.get('expiring_within') ?? '0', 10);

    let query = sb
      .from('profiles')
      .select(`id, full_name, residency_type, move_in_date, is_active,
               num_occupants, nri_flag, phone_encrypted,
               units!inner(unit_number, block, floor, area_sqft, unit_type, occupancy_status)`)
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('full_name')
      .limit(2000);

    if (q)           query = query.ilike('full_name', `%${q}%`);
    if (blockFilter) query = query.eq('units.block', blockFilter);
    if (occupancy)   query = query.eq('units.occupancy_status', occupancy);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const memberIds = (data ?? []).map((m: any) => m.id);

    const { data: roles } = memberIds.length
      ? await sb.from('user_roles').select('user_id, role').in('user_id', memberIds).eq('society_id', SOCIETY_ID)
      : { data: [] };
    const roleMap: Record<string, string> = {};
    for (const r of roles ?? []) roleMap[r.user_id] = r.role;

    let emailMap: Record<string, string> = {};
    if (memberIds.length) {
      try {
        const { data: authData } = await sb.auth.admin.listUsers({ perPage: 1000 });
        const memberIdSet = new Set(memberIds);
        for (const u of authData?.users ?? []) {
          if (memberIdSet.has(u.id) && u.email) emailMap[u.id] = u.email;
        }
      } catch {
        // Non-fatal
      }
    }

    let expiringUnitIds = new Set<string>();
    if (expiringDays > 0) {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() + expiringDays);
      const { data: expiring } = await sb
        .from('tenancies')
        .select('unit_id')
        .eq('society_id', SOCIETY_ID)
        .eq('is_active', true)
        .lte('lease_end', cutoff.toISOString().slice(0, 10));
      (expiring ?? []).forEach((t: any) => expiringUnitIds.add(t.unit_id));
    }

    const rows = (data ?? [])
      .filter((m: any) => !expiringDays || expiringUnitIds.has(m.units?.id))
      .map((m: any) => [
        m.full_name ?? '',
        m.units?.block ?? '',
        m.units?.unit_number ?? '',
        m.units?.floor ?? '',
        m.units?.area_sqft ?? '',
        m.units?.unit_type ?? '',
        m.units?.occupancy_status ?? '',
        m.residency_type ?? '',
        roleMap[m.id] ?? 'member',
        m.num_occupants ?? '',
        m.nri_flag ? 'Yes' : 'No',
        m.move_in_date ?? '',
        emailMap[m.id] ?? '',
        m.phone_encrypted ?? '',
      ]);

    const headers = [
      'Name', 'Block', 'Unit', 'Floor', 'Area (sqft)', 'Unit Type',
      'Occupancy Status', 'Residency Type', 'Role', 'Occupants',
      'NRI', 'Move-in Date', 'Email', 'Phone',
    ];

    const escape = (v: string) => {
      const s = String(v);
      return s.includes(',') || s.includes('"') || s.includes('\n')
        ? `"${s.replace(/"/g, '""')}"`
        : s;
    };

    const csv = [headers, ...rows]
      .map(row => row.map(escape).join(','))
      .join('\r\n');

    const today = new Date().toISOString().slice(0, 10);
    return new Response(csv, {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="members-${today}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
