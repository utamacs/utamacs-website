export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getRules, ruleStr } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const EXEC_TRANSITIONS: Record<string, string[]> = {
  applied:         ['fees_pending', 'fees_confirmed', 'approved', 'rejected'],
  fees_pending:    ['fees_confirmed', 'applied', 'rejected'],
  fees_confirmed:  ['approved', 'fees_pending', 'rejected'],
  approved:        ['suspended', 'transferred', 'deceased'],
  suspended:       ['approved'],
  transferred:     [],
  deceased:        [],
  rejected:        [],
};

// PATCH /api/v1/memberships/[id]
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    const { data: membership, error: fetchErr } = await sb
      .from('memberships')
      .select('*')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !membership) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;
    const isOwner = membership.profile_id === user.id;

    if (!isPrivileged && !isOwner) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const body = await request.json() as Record<string, unknown>;
    const updates: Record<string, unknown> = {};
    let approving = false;

    if (body.status !== undefined && isPrivileged) {
      const newStatus = String(body.status);
      const allowed = EXEC_TRANSITIONS[membership.status] ?? [];
      if (!allowed.includes(newStatus)) {
        return Response.json({
          error: 'VALIDATION',
          message: `Cannot transition from '${membership.status}' to '${newStatus}'`,
        }, { status: 400 });
      }
      updates.status = newStatus;

      if (newStatus === 'approved') {
        approving = true;
        updates.voting_eligible = (membership.admission_fee_paid && membership.share_capital_paid);
        updates.reviewed_by = user.id;
        updates.reviewed_at = new Date().toISOString();
        if (!membership.admission_fee_paid || !membership.share_capital_paid) {
          updates.voting_eligible = false;
          updates.voting_disqualified_reason = 'Fees not fully confirmed — voting eligibility pending fee confirmation';
        }
      }
      if (newStatus === 'rejected') {
        updates.voting_eligible = false;
        updates.reviewed_by = user.id;
        updates.reviewed_at = new Date().toISOString();
        const reason = sanitizePlainText(String(body.rejection_reason ?? '')).trim();
        if (!reason) return Response.json({ error: 'VALIDATION', message: 'rejection_reason required' }, { status: 400 });
        updates.rejection_reason = reason.slice(0, 500);
      }
      if (newStatus === 'suspended') {
        updates.voting_eligible = false;
        updates.voting_disqualified_reason = sanitizePlainText(String(body.voting_disqualified_reason ?? '')).trim().slice(0, 300) || 'Membership suspended';
      }
    }

    if (isPrivileged) {
      if (body.admission_fee_paid === true && !membership.admission_fee_paid) {
        updates.admission_fee_paid = true;
        updates.admission_fee_paid_at = new Date().toISOString();
      }
      if (body.admission_fee_receipt_no !== undefined) {
        updates.admission_fee_receipt_no = sanitizePlainText(String(body.admission_fee_receipt_no)).trim().slice(0, 100) || null;
      }
      if (body.share_capital_paid === true && !membership.share_capital_paid) {
        updates.share_capital_paid = true;
        updates.share_capital_paid_at = new Date().toISOString();
      }
      if (body.byelaw_copy_fee_paid === true) {
        updates.byelaw_copy_fee_paid = true;
      }
      if (body.share_certificate_number !== undefined) {
        const certNum = sanitizePlainText(String(body.share_certificate_number)).trim();
        if (!certNum) return Response.json({ error: 'VALIDATION', message: 'share_certificate_number cannot be empty' }, { status: 400 });
        if (membership.status !== 'approved' && updates.status !== 'approved') {
          return Response.json({ error: 'VALIDATION', message: 'Share certificate can only be issued after membership is approved (Byelaw §4.12)' }, { status: 400 });
        }
        updates.share_certificate_number = certNum.slice(0, 30);
        updates.share_certificate_issued_at = new Date().toISOString();
        const feesConfirmed = (updates.admission_fee_paid ?? membership.admission_fee_paid) &&
                              (updates.share_capital_paid ?? membership.share_capital_paid);
        if (feesConfirmed) {
          updates.voting_eligible = true;
          updates.voting_disqualified_reason = null;
        }
      }
      if (body.membership_number !== undefined) {
        updates.membership_number = sanitizePlainText(String(body.membership_number)).trim().slice(0, 30) || null;
      }
      if (body.termination_reason !== undefined) {
        updates.termination_reason = sanitizePlainText(String(body.termination_reason)).trim().slice(0, 300) || null;
      }
      if (body.effective_to !== undefined) {
        updates.effective_to = body.effective_to || null;
      }
      if (body.voting_eligible !== undefined) {
        updates.voting_eligible = body.voting_eligible === true;
        if (!updates.voting_eligible && body.voting_disqualified_reason) {
          updates.voting_disqualified_reason = sanitizePlainText(String(body.voting_disqualified_reason)).trim().slice(0, 300);
        }
      }
      if (body.linked_registration_id !== undefined) {
        const regId = String(body.linked_registration_id);
        updates.linked_registration_id = UUID_RE.test(regId) ? regId : null;
      }
    }

    // Member-editable fields (only when status = 'applied')
    if (isOwner && membership.status === 'applied') {
      if (body.sale_deed_number !== undefined) {
        updates.sale_deed_number = sanitizePlainText(String(body.sale_deed_number ?? '')).trim().slice(0, 100) || null;
      }
      if (body.sale_deed_date !== undefined) {
        updates.sale_deed_date = body.sale_deed_date || null;
      }
      if (body.registration_office !== undefined) {
        updates.registration_office = sanitizePlainText(String(body.registration_office ?? '')).trim().slice(0, 200) || null;
      }
      if (body.joint_owner_names !== undefined && Array.isArray(body.joint_owner_names)) {
        updates.joint_owner_names = (body.joint_owner_names as unknown[])
          .map(n => sanitizePlainText(String(n)).trim())
          .filter(Boolean);
      }
    }

    if (Object.keys(updates).length === 0) {
      return Response.json({ error: 'VALIDATION', message: 'No updatable fields provided' }, { status: 400 });
    }

    const { data, error: updateErr } = await sb
      .from('memberships')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (updateErr) {
      if (updateErr.code === '23505') {
        return Response.json({ error: 'CONFLICT', message: 'Share certificate number or membership number already in use' }, { status: 409 });
      }
      throw Object.assign(new Error(updateErr.message), { status: 500 });
    }

    // When membership is approved, check MEMBERSHIP_PORTAL_LINK_MODE and auto-approve
    // linked portal registration if the mode allows it
    if (approving && membership.linked_registration_id) {
      const rules = await getRules(sb, SOCIETY_ID, ['MEMBERSHIP_PORTAL_LINK_MODE']);
      const linkMode = ruleStr(rules, 'MEMBERSHIP_PORTAL_LINK_MODE', 'auto_approve');

      if (linkMode === 'auto_approve') {
        await sb
          .from('registration_requests')
          .update({
            status: 'approved',
            reviewed_by: user.id,
            reviewed_at: new Date().toISOString(),
            // Note: created_profile_id should already be set if the member has a portal account
          })
          .eq('id', membership.linked_registration_id)
          .eq('status', 'pending'); // only if still pending

        await writeAuditLog({
          userId: user.id,
          action: 'UPDATE',
          resourceType: 'registration_request',
          resourceId: membership.linked_registration_id,
          oldValues: { status: 'pending' },
          newValues: { status: 'approved', reason: `Auto-approved on byelaw membership approval (mode: ${linkMode})` },
        });
      }
    }

    await writeAuditLog({
      userId: user.id,
      action: 'UPDATE',
      resourceType: 'membership',
      resourceId: id,
      oldValues: { status: membership.status, voting_eligible: membership.voting_eligible },
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// GET /api/v1/memberships/[id]
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;

    let query = sb
      .from('memberships')
      .select(`*, units!memberships_unit_id_fkey(unit_number, block)`)
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (!isPrivileged) query = query.eq('profile_id', user.id);

    const { data, error } = await query.single();
    if (error || !data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
