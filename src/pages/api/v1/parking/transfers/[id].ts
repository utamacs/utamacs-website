export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PATCH — exec approves or rejects a pending parking slot transfer
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const transferId = params.id ?? '';
    if (!UUID_RE.test(transferId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const body = await request.json() as { action: 'approve' | 'reject'; rejection_note?: string };
    if (!['approve','reject'].includes(body.action)) {
      return Response.json({ error: 'VALIDATION', message: 'action must be "approve" or "reject".' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: transfer } = await sb
      .from('parking_slot_transfers')
      .select('id, slot_id, from_unit_id, to_unit_id, status, requested_by, society_id')
      .eq('id', transferId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!transfer) return Response.json({ error: 'NOT_FOUND', message: 'Transfer request not found.' }, { status: 404 });
    if (transfer.status !== 'pending') {
      return Response.json({ error: 'CONFLICT', message: `Transfer is already ${transfer.status}.` }, { status: 409 });
    }

    if (body.action === 'reject') {
      const note = body.rejection_note?.trim().slice(0, 300) || null;
      await sb.from('parking_slot_transfers').update({
        status:         'rejected',
        approved_by:    user.id,
        approved_at:    new Date().toISOString(),
        rejection_note: note,
      }).eq('id', transferId);

      // Parking audit log
      await sb.from('parking_audit').insert({
        society_id:    SOCIETY_ID,
        slot_id:       transfer.slot_id,
        action:        'TRANSFER_REJECTED',
        actor_id:      user.id,
        unit_id:       transfer.from_unit_id,
        notes:         note,
      });

      await writeAuditLog({
        userId: user.id,
        societyId: SOCIETY_ID,
        action: 'UPDATE',
        resourceType: 'parking_slot_transfer',
        resourceId: transferId,
        ip: extractClientIP(request),
        newValues: { status: 'rejected', rejection_note: note },
      });

      return Response.json({ id: transferId, status: 'rejected' });
    }

    // Approve: transfer the active allocation to the new unit
    // 1. Find the active allocation for this slot
    const { data: alloc } = await sb
      .from('parking_allocations')
      .select('id, user_id')
      .eq('slot_id', transfer.slot_id)
      .eq('status', 'active')
      .maybeSingle();

    if (!alloc) {
      return Response.json({ error: 'CONFLICT', message: 'No active allocation found for this slot to transfer.' }, { status: 409 });
    }

    // 2. Find a user in the target unit to reassign to
    const { data: targetProfile } = await sb
      .from('profiles')
      .select('id')
      .eq('unit_id', transfer.to_unit_id)
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .limit(1)
      .maybeSingle();

    if (!targetProfile) {
      return Response.json({ error: 'CONFLICT', message: 'No active member found in the destination unit.' }, { status: 409 });
    }

    // 3. Update allocation: new unit and user
    await sb.from('parking_allocations').update({
      unit_id: transfer.to_unit_id,
      user_id: targetProfile.id,
      updated_at: new Date().toISOString(),
    }).eq('id', alloc.id);

    // 4. Mark transfer approved
    await sb.from('parking_slot_transfers').update({
      status:      'approved',
      approved_by: user.id,
      approved_at: new Date().toISOString(),
    }).eq('id', transferId);

    // 5. Parking audit log
    await sb.from('parking_audit').insert({
      society_id:    SOCIETY_ID,
      slot_id:       transfer.slot_id,
      allocation_id: alloc.id,
      action:        'TRANSFER_APPROVED',
      actor_id:      user.id,
      unit_id:       transfer.to_unit_id,
      notes:         `Transferred from unit ${transfer.from_unit_id} to ${transfer.to_unit_id}`,
    });

    await writeAuditLog({
      userId: user.id,
      societyId: SOCIETY_ID,
      action: 'UPDATE',
      resourceType: 'parking_slot_transfer',
      resourceId: transferId,
      ip: extractClientIP(request),
      newValues: { status: 'approved', new_unit_id: transfer.to_unit_id },
    });

    return Response.json({ id: transferId, status: 'approved', allocation_id: alloc.id });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
