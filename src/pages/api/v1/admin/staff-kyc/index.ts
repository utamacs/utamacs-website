export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/admin/staff-kyc — list all staff with KYC status
// Exec/admin only
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();

    const rules = await getRules(sb, SOCIETY_ID, ['STAFF_PASS_EXPIRY_WARNING_DAYS']);
    const warningDays = ruleInt(rules, 'STAFF_PASS_EXPIRY_WARNING_DAYS', 30);

    const kycStatus = url.searchParams.get('kyc_status');
    const passExpiring = url.searchParams.get('pass_expiring');
    const type = url.searchParams.get('type') ?? 'staff'; // 'staff' | 'maid'

    if (type === 'maid') {
      let query = sb
        .from('maids')
        .select(`
          id, full_name, phone, work_type,
          photo_key, id_doc_key, id_type, id_number,
          police_verified, verification_date, verification_ref,
          security_pass_issued, security_pass_issued_at, security_pass_number, security_pass_expires_at,
          two_photos_received, kyc_status, is_active, created_at,
          maid_unit_approvals(unit_id, is_active)
        `)
        .eq('society_id', SOCIETY_ID)
        .order('full_name');

      if (kycStatus) query = query.eq('kyc_status', kycStatus);
      if (passExpiring === 'true') {
        const threshold = new Date(Date.now() + warningDays * 24 * 60 * 60 * 1000).toISOString();
        query = query.lte('security_pass_expires_at', threshold).eq('security_pass_issued', true);
      }

      const { data, error } = await query;
      if (error) throw Object.assign(new Error(error.message), { status: 500 });
      return Response.json(data ?? []);
    }

    // Default: staff members
    let query = sb
      .from('staff_members')
      .select(`
        id, name, role, phone, joining_date, is_active,
        photo_key, id_doc_key, aadhaar_last4, id_proof_type,
        police_verified, police_verification_date, police_verification_ref, police_station,
        two_photos_received, security_pass_issued, security_pass_issued_at,
        security_pass_number, security_pass_expires_at,
        kyc_status, background_remarks, created_at
      `)
      .eq('society_id', SOCIETY_ID)
      .order('name');

    if (kycStatus) query = query.eq('kyc_status', kycStatus);
    if (passExpiring === 'true') {
      const threshold = new Date(Date.now() + warningDays * 24 * 60 * 60 * 1000).toISOString();
      query = query.lte('security_pass_expires_at', threshold).eq('security_pass_issued', true);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
