export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature, hasFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_WORK_TYPES = ['cleaning','cooking','babysitting','elder_care','gardening','laundry','multiple','other'];
const VALID_ID_TYPES   = ['aadhaar','voter_id','passport','dl','other'];

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.view');
    const sb = getSupabaseServiceClient();
    const isPrivileged = hasFeature(user, 'maids.manage');
    const url = new URL(request.url);
    const activeOnly = url.searchParams.get('active') !== 'false';
    const search = url.searchParams.get('q')?.trim() ?? '';

    let query = sb
      .from('maids')
      .select(`
        id, full_name, phone, work_type, agency_name,
        is_active, police_verified, verification_date, kyc_expires_at,
        photo_key, id_type, registered_at,
        maid_unit_approvals!inner(unit_id, is_active)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('full_name');

    if (activeOnly) query = (query as any).eq('is_active', true);
    if (search) query = (query as any).ilike('full_name', `%${search}%`);

    // Members see only maids approved for their unit
    if (!isPrivileged) {
      // Fetch member's unit_id
      const { data: profile } = await sb
        .from('profiles')
        .select('unit_id')
        .eq('id', user.id)
        .single();
      const unitId = (profile as any)?.unit_id;
      if (!unitId) return Response.json([]);

      // Maids approved for this unit
      const { data: approved } = await sb
        .from('maid_unit_approvals')
        .select('maid_id')
        .eq('unit_id', unitId)
        .eq('is_active', true);

      const approvedIds = ((approved ?? []) as any[]).map((a: any) => a.maid_id);
      if (!approvedIds.length) return Response.json([]);

      // Fetch those specific maids without the inner join filter
      const { data: maids, error } = await sb
        .from('maids')
        .select('id, full_name, work_type, agency_name, is_active, police_verified, photo_key, registered_at')
        .eq('society_id', SOCIETY_ID)
        .in('id', approvedIds)
        .eq('is_active', true)
        .order('full_name');

      if (error) throw error;
      return Response.json(maids ?? []);
    }

    // Exec: all maids (no inner join restriction)
    const { data, error } = await sb
      .from('maids')
      .select('id, full_name, phone, work_type, agency_name, is_active, police_verified, verification_date, photo_key, id_type, registered_at')
      .eq('society_id', SOCIETY_ID)
      .order('full_name');

    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.manage');

    const body = await request.json() as Record<string, unknown>;
    const full_name = String(body.full_name ?? '').trim();
    if (full_name.length < 2) {
      return Response.json({ error: 'VALIDATION', message: 'Full name is required (min 2 characters).' }, { status: 400 });
    }

    const work_type = String(body.work_type ?? 'cleaning');
    if (!VALID_WORK_TYPES.includes(work_type)) {
      return Response.json({ error: 'INVALID_WORK_TYPE' }, { status: 400 });
    }

    const id_type = body.id_type ? String(body.id_type) : null;
    if (id_type && !VALID_ID_TYPES.includes(id_type)) {
      return Response.json({ error: 'INVALID_ID_TYPE' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('maids')
      .insert({
        society_id: SOCIETY_ID,
        full_name: sanitizePlainText(full_name).slice(0, 100),
        phone:       body.phone       ? sanitizePlainText(String(body.phone)).slice(0, 15)       : null,
        id_type,
        id_number:   body.id_number   ? sanitizePlainText(String(body.id_number)).slice(0, 30)   : null,
        agency_name: body.agency_name ? sanitizePlainText(String(body.agency_name)).slice(0, 100) : null,
        work_type,
        police_verified:  body.police_verified === true,
        verification_date: body.verification_date ? String(body.verification_date) : null,
        verified_by: body.police_verified === true ? user.id : null,
      })
      .select()
      .single();

    if (error) throw error;

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'CREATE', resourceType: 'maid',
      resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { full_name, work_type },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
