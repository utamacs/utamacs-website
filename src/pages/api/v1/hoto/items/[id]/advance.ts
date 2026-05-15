export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, hasFeature } from '@lib/permissions';
import type { Feature } from '@lib/features';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// State machine transition map:
// key = "FROM:TO", value = { feature required, extraCheck }
const TRANSITIONS: Record<string, {
  feature: Feature;
  secretaryPlus?: boolean;   // requires secretary or president role
  docRequired?: boolean;     // requires ≥1 governance_file attached
  recordPresidentApproval?: boolean;
  recordSecretaryApproval?: boolean;
  differentFromPresidentApprover?: boolean;
  requireGovernanceNotes?: boolean;
}> = {
  'NOT_STARTED:IN_PROGRESS':              { feature: 'hoto.advance_status' },
  'IN_PROGRESS:UNDER_REVIEW':             { feature: 'hoto.advance_status', docRequired: true },
  'UNDER_REVIEW:PENDING_PRESIDENT':       { feature: 'hoto.advance_status', secretaryPlus: true },
  'PENDING_PRESIDENT:PENDING_SECRETARY':  { feature: 'hoto.approve_president', recordPresidentApproval: true },
  'PENDING_SECRETARY:APPROVED':           { feature: 'hoto.approve_secretary', differentFromPresidentApprover: true, recordSecretaryApproval: true },
  'APPROVED:CLOSED':                      { feature: 'hoto.advance_status', secretaryPlus: true },
  // Send back from APPROVED to IN_PROGRESS (secretary/president can reopen for corrections)
  'APPROVED:IN_PROGRESS':                 { feature: 'hoto.advance_status', secretaryPlus: true, requireGovernanceNotes: true },
  // Dispute path (from any reviewable state back to disputed)
  'UNDER_REVIEW:REJECTED':                { feature: 'hoto.advance_status', secretaryPlus: true, requireGovernanceNotes: true },
  'PENDING_PRESIDENT:REJECTED':           { feature: 'hoto.advance_status', secretaryPlus: true, requireGovernanceNotes: true },
  'PENDING_SECRETARY:REJECTED':           { feature: 'hoto.advance_status', secretaryPlus: true, requireGovernanceNotes: true },
  'APPROVED:REJECTED':                    { feature: 'hoto.advance_status', secretaryPlus: true, requireGovernanceNotes: true },
  // Reopen from REJECTED back to IN_PROGRESS
  'REJECTED:IN_PROGRESS':                 { feature: 'hoto.advance_status' },
};

// POST — advance HOTO item through state machine
// Auth: varies by transition (see TRANSITIONS map)
// Body: { to_status, governance_notes? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });

    const itemId = params.id!;
    const body = await request.json() as { to_status?: string; governance_notes?: string };

    if (!body.to_status?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'to_status is required' }, { status: 400 });
    }

    const toStatus = body.to_status.trim();
    const sb = getSupabaseServiceClient();

    // Fetch current item
    const { data: item, error: fetchErr } = await sb
      .from('hoto_items')
      .select('id, status, president_approved_by, responsible_user_id')
      .eq('id', itemId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !item) {
      return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found' }, { status: 404 });
    }

    const fromStatus = (item as any).status as string;
    const transitionKey = `${fromStatus}:${toStatus}`;
    const rule = TRANSITIONS[transitionKey];

    if (!rule) {
      return Response.json({
        error: 'INVALID_TRANSITION',
        message: `Cannot transition from '${fromStatus}' to '${toStatus}'`,
      }, { status: 400 });
    }

    // Check required feature
    if (!hasFeature(user, rule.feature)) {
      return Response.json({
        error: 'FORBIDDEN',
        message: `This transition requires the '${rule.feature}' permission`,
      }, { status: 403 });
    }

    // Check secretary+ requirement
    if (rule.secretaryPlus) {
      const allowedRoles = new Set(['secretary', 'president']);
      if (!allowedRoles.has(user.portalRole) && !user.isAdmin) {
        return Response.json({
          error: 'FORBIDDEN',
          message: 'This transition requires Secretary or President role',
        }, { status: 403 });
      }
    }

    // Check governance_notes requirement
    if (rule.requireGovernanceNotes && !body.governance_notes?.trim()) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: 'governance_notes is required for this transition',
      }, { status: 400 });
    }

    // Check doc_required: at least one governance_file must be attached
    if (rule.docRequired) {
      const { count } = await sb
        .from('governance_files')
        .select('id', { count: 'exact', head: true })
        .eq('item_type', 'hoto_item')
        .eq('item_id', itemId)
        .is('superseded_by', null);

      const hasDoc = typeof count === 'number' && count > 0;
      if (!hasDoc) {
        // Allow bypass if user has hoto.bypass_required_docs AND all required docs are either uploaded or bypassed
        if (!hasFeature(user, 'hoto.bypass_required_docs')) {
          return Response.json({
            error: 'PRECONDITION_FAILED',
            message: 'At least one document must be uploaded before advancing to UNDER_REVIEW',
          }, { status: 422 });
        }
      }
    }

    // Check separation of duties: secretary approver ≠ president approver
    if (rule.differentFromPresidentApprover) {
      const presidentApprovedBy = (item as any).president_approved_by as string | null;
      if (presidentApprovedBy && presidentApprovedBy === user.id) {
        return Response.json({
          error: 'FORBIDDEN',
          message: 'The same person cannot approve at both the President and Secretary stages',
        }, { status: 403 });
      }
    }

    // Build the update payload
    const updates: Record<string, unknown> = { status: toStatus };
    if (body.governance_notes?.trim()) {
      updates.governance_notes = body.governance_notes.trim();
    }
    if (rule.recordPresidentApproval) {
      updates.president_approved_by = user.id;
      updates.president_approved_at = new Date().toISOString();
    }
    if (rule.recordSecretaryApproval) {
      updates.secretary_approved_by = user.id;
      updates.secretary_approved_at = new Date().toISOString();
    }

    const { data: updated, error: updateErr } = await sb
      .from('hoto_items')
      .update(updates)
      .eq('id', itemId)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // Write to hoto_audit_log
    const { error: auditHotoErr } = await sb.from('hoto_audit_log').insert({
      society_id: SOCIETY_ID,
      actor_id: user.id,
      action: 'STATUS_CHANGE',
      resource_type: 'hoto_items',
      resource_id: itemId,
      old_values: { status: fromStatus },
      new_values: {
        status: toStatus,
        ...(body.governance_notes ? { governance_notes: body.governance_notes.trim() } : {}),
      },
    });
    if (auditHotoErr) console.error('[advance] hoto_audit_log insert failed:', auditHotoErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'hoto_items', resourceId: itemId,
      ip: extractClientIP(request),
      oldValues: { status: fromStatus },
      newValues: { status: toStatus },
    });

    return Response.json({ success: true, item: updated });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
