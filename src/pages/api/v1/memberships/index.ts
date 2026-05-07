export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_STATUSES = ['applied','fees_pending','fees_confirmed','approved','suspended','transferred','deceased','rejected'] as const;
const VALID_TYPES = ['original_owner','purchaser','successor','heir','joint_owner_nominee'] as const;

// GET /api/v1/memberships
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;

    const status = url.searchParams.get('status');
    const unitId = url.searchParams.get('unit_id');

    let query = sb
      .from('memberships')
      .select(`
        id, unit_id, profile_id, member_name, member_type, joint_owner_names,
        sale_deed_number, sale_deed_date, registration_office,
        admission_fee_amount, admission_fee_paid, admission_fee_paid_at, admission_fee_receipt_no,
        share_capital_amount, share_capital_paid, share_capital_paid_at,
        byelaw_copy_fee_paid,
        share_certificate_number, share_certificate_issued_at,
        membership_number, status, voting_eligible, voting_disqualified_reason,
        declaration_signed, declaration_signed_at,
        submitted_at, reviewed_by, reviewed_at, rejection_reason,
        effective_to, termination_reason, linked_registration_id, created_at,
        units!memberships_unit_id_fkey(unit_number, block)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (!isPrivileged) query = query.eq('profile_id', user.id);

    if (status && VALID_STATUSES.includes(status as typeof VALID_STATUSES[number])) {
      query = query.eq('status', status);
    }
    if (unitId && UUID_RE.test(unitId)) {
      query = query.eq('unit_id', unitId);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/memberships — submit membership application
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const body = await request.json() as Record<string, unknown>;

    const unit_id      = String(body.unit_id ?? '');
    const member_name  = sanitizePlainText(String(body.member_name ?? '')).trim();
    const member_type  = String(body.member_type ?? 'original_owner');
    const sale_deed_number   = sanitizePlainText(String(body.sale_deed_number ?? '')).trim();
    const sale_deed_date     = body.sale_deed_date ? String(body.sale_deed_date) : null;
    const registration_office = sanitizePlainText(String(body.registration_office ?? '')).trim();
    const joint_owner_names  = Array.isArray(body.joint_owner_names)
      ? (body.joint_owner_names as unknown[]).map(n => sanitizePlainText(String(n)).trim()).filter(Boolean)
      : [];
    const declaration_signed = body.declaration_signed === true;

    if (!UUID_RE.test(unit_id)) {
      return Response.json({ error: 'VALIDATION', message: 'Valid unit_id required' }, { status: 400 });
    }
    if (!member_name) {
      return Response.json({ error: 'VALIDATION', message: 'member_name required' }, { status: 400 });
    }
    if (!VALID_TYPES.includes(member_type as typeof VALID_TYPES[number])) {
      return Response.json({ error: 'VALIDATION', message: `member_type must be one of: ${VALID_TYPES.join(', ')}` }, { status: 400 });
    }
    if (!declaration_signed) {
      return Response.json({ error: 'VALIDATION', message: 'declaration_signed must be true — member must agree to byelaws' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Read fee amounts from rules engine (Byelaw §4.1)
    const rules = await getRules(sb, SOCIETY_ID, ['MEMBERSHIP_ADMISSION_FEE', 'MEMBERSHIP_SHARE_CAPITAL']);
    const admissionFee = ruleInt(rules, 'MEMBERSHIP_ADMISSION_FEE', 1000);
    const shareCapital = ruleInt(rules, 'MEMBERSHIP_SHARE_CAPITAL', 1000);

    // Verify unit belongs to this society
    const { data: unit } = await sb
      .from('units')
      .select('id')
      .eq('id', unit_id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!unit) return Response.json({ error: 'NOT_FOUND', message: 'Unit not found' }, { status: 404 });

    // Check for existing active/pending membership (Byelaw §4.4 one-per-flat)
    const { data: existing } = await sb
      .from('memberships')
      .select('id, status, member_name')
      .eq('unit_id', unit_id)
      .not('status', 'in', '("rejected","transferred","deceased")')
      .maybeSingle();

    if (existing) {
      return Response.json({
        error: 'CONFLICT',
        message: `This flat already has an active/pending membership (Byelaw §4.4 one-per-flat). Member: ${existing.member_name}, Status: ${existing.status}`,
      }, { status: 409 });
    }

    // Check for a linked portal registration for this user/unit
    const { data: existingReg } = await sb
      .from('registration_requests')
      .select('id')
      .eq('society_id', SOCIETY_ID)
      .eq('unit_id', unit_id)
      .eq('status', 'pending')
      .maybeSingle();

    const { data, error } = await sb
      .from('memberships')
      .insert({
        society_id: SOCIETY_ID,
        unit_id,
        profile_id: user.id,
        member_name: member_name.slice(0, 100),
        member_type,
        joint_owner_names,
        sale_deed_number: sale_deed_number.slice(0, 100) || null,
        sale_deed_date: sale_deed_date || null,
        registration_office: registration_office.slice(0, 200) || null,
        declaration_signed,
        declaration_signed_at: declaration_signed ? new Date().toISOString() : null,
        admission_fee_amount: admissionFee,
        share_capital_amount: shareCapital,
        status: 'applied',
        submitted_at: new Date().toISOString(),
        linked_registration_id: existingReg?.id ?? null,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return Response.json({ error: 'CONFLICT', message: 'This flat already has an active membership application (Byelaw §4.4 one-per-flat rule)' }, { status: 409 });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    // If there's a linked registration_request, update its membership_id
    if (existingReg?.id && data) {
      await sb
        .from('registration_requests')
        .update({ membership_id: data.id })
        .eq('id', existingReg.id);
    }

    return Response.json({
      ...data,
      _fees: { admission_fee: admissionFee, share_capital: shareCapital, total: admissionFee + shareCapital },
    }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
