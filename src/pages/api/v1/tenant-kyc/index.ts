export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_STATUSES = ['pending', 'submitted', 'police_verified', 'completed', 'expired'] as const;

// GET /api/v1/tenant-kyc — list KYC records
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const statusFilter = url.searchParams.get('status');
    const unitId = url.searchParams.get('unit_id');
    const pending = url.searchParams.get('pending') === 'true';

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;

    let query = sb
      .from('tenant_kyc')
      .select('id, unit_id, profile_id, full_name, nationality, aadhaar_last4, tenancy_start_date, tenancy_end_date, monthly_rent, police_verified, police_station, verification_date, verification_ref, owner_profile_id, owner_consent, status, notes, created_at, updated_at, units(unit_number, block)')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (!isPrivileged) {
      // Members see only their own records (as tenant or owner)
      query = query.or(`profile_id.eq.${user.id},owner_profile_id.eq.${user.id}`);
    }

    if (statusFilter && VALID_STATUSES.includes(statusFilter as typeof VALID_STATUSES[number])) {
      query = query.eq('status', statusFilter);
    }
    if (unitId && UUID_RE.test(unitId)) query = query.eq('unit_id', unitId);
    if (pending) query = query.not('status', 'in', '("completed","expired")');

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/tenant-kyc — create a new KYC record (exec only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const full_name = sanitizePlainText(String(body.full_name ?? '')).trim();
    const unit_id = String(body.unit_id ?? '');
    const tenancy_start_date = String(body.tenancy_start_date ?? '');

    if (!full_name) return Response.json({ error: 'VALIDATION', message: 'full_name required' }, { status: 400 });
    if (!UUID_RE.test(unit_id)) return Response.json({ error: 'VALIDATION', message: 'Valid unit_id required' }, { status: 400 });
    if (!/^\d{4}-\d{2}-\d{2}$/.test(tenancy_start_date)) return Response.json({ error: 'VALIDATION', message: 'tenancy_start_date must be YYYY-MM-DD' }, { status: 400 });

    const aadhaar_last4 = body.aadhaar_last4 ? String(body.aadhaar_last4) : null;
    if (aadhaar_last4 && !/^\d{4}$/.test(aadhaar_last4)) return Response.json({ error: 'VALIDATION', message: 'aadhaar_last4 must be exactly 4 digits' }, { status: 400 });

    const pan_number = body.pan_number ? String(body.pan_number).toUpperCase().trim() : null;
    if (pan_number && !/^[A-Z]{5}[0-9]{4}[A-Z]$/.test(pan_number)) return Response.json({ error: 'VALIDATION', message: 'Invalid PAN format' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('tenant_kyc')
      .insert({
        society_id: SOCIETY_ID,
        unit_id,
        profile_id: body.profile_id && UUID_RE.test(String(body.profile_id)) ? String(body.profile_id) : null,
        owner_profile_id: body.owner_profile_id && UUID_RE.test(String(body.owner_profile_id)) ? String(body.owner_profile_id) : null,
        full_name,
        date_of_birth: body.date_of_birth ? String(body.date_of_birth) : null,
        nationality: body.nationality ? sanitizePlainText(String(body.nationality)).slice(0, 100) : 'Indian',
        aadhaar_last4: aadhaar_last4 ?? null,
        pan_number: pan_number ?? null,
        tenancy_start_date,
        tenancy_end_date: body.tenancy_end_date ? String(body.tenancy_end_date) : null,
        monthly_rent: body.monthly_rent ? Number(body.monthly_rent) : null,
        notes: body.notes ? sanitizePlainText(String(body.notes)).slice(0, 1000) : null,
        status: 'pending',
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'tenant_kyc', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { unit_id, full_name, tenancy_start_date },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
