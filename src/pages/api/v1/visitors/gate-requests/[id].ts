export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PUT /api/v1/visitors/gate-requests/{id}
// Resident (or exec) approves or rejects a pending gate request.
// Body: { action: 'approve' | 'reject', note?: string }
// On approve: also creates a visitor_log entry and returns log_id.
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const { id } = params;
    if (!id || !UUID_RE.test(id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Invalid request id' }, { status: 400 });
    }

    const body = await request.json() as { action?: 'approve' | 'reject'; note?: string };
    if (!body.action || !['approve', 'reject'].includes(body.action)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'action must be approve or reject' }, { status: 400 });
    }

    const isPrivileged = user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
    const sb = getSupabaseServiceClient();

    // Fetch the request
    const { data: gateReq, error: fetchErr } = await sb
      .from('visitor_gate_requests')
      .select('id, visitor_name, visitor_type, vehicle_number, host_unit_id, status, expires_at, requested_by')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !gateReq) {
      return Response.json({ error: 'NOT_FOUND', message: 'Gate request not found' }, { status: 404 });
    }

    if (gateReq.status !== 'pending') {
      return Response.json({ error: 'ALREADY_DECIDED', message: `This request has already been ${gateReq.status}` }, { status: 409 });
    }

    if (new Date(gateReq.expires_at) < new Date()) {
      // Mark expired and return error
      await sb.from('visitor_gate_requests').update({ status: 'expired' }).eq('id', id);
      return Response.json({ error: 'EXPIRED', message: 'This gate request has expired' }, { status: 410 });
    }

    // Verify the user is a resident of the host unit, or exec/admin
    if (!isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      if (!profile?.unit_id || profile.unit_id !== gateReq.host_unit_id) {
        return Response.json({ error: 'FORBIDDEN', message: 'You can only decide gate requests for your own flat' }, { status: 403 });
      }
    }

    const now = new Date().toISOString();
    let logId: string | null = null;

    if (body.action === 'approve') {
      // Create a visitor_log entry
      const { data: logEntry } = await sb.from('visitor_logs').insert({
        society_id:   SOCIETY_ID,
        visitor_name: gateReq.visitor_name,
        host_unit_id: gateReq.host_unit_id,
        entry_type:   'walk_in',
        visitor_type: gateReq.visitor_type ?? null,
        vehicle_number: gateReq.vehicle_number ?? null,
        entry_time:   now,
        logged_by:    gateReq.requested_by, // guard who initiated
      }).select('id').single();
      logId = logEntry?.id ?? null;
    }

    // Update the gate request
    await sb.from('visitor_gate_requests').update({
      status:        body.action === 'approve' ? 'approved' : 'rejected',
      approved_by:   user.id,
      decision_note: body.note?.trim().slice(0, 300) ?? null,
      decided_at:    now,
    }).eq('id', id);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'visitor_gate_request', resourceId: id,
      ip: extractClientIP(request),
      newValues: { action: body.action, log_id: logId, note: body.note },
    });

    return Response.json({
      ok: true,
      action: body.action,
      visitor_name: gateReq.visitor_name,
      log_id: logId,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/visitors/gate-requests/{id} — guard cancels their own pending request
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const { id } = params;
    if (!id || !UUID_RE.test(id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Invalid request id' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data: gateReq } = await sb
      .from('visitor_gate_requests')
      .select('id, requested_by, status')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!gateReq) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (gateReq.status !== 'pending') {
      return Response.json({ error: 'ALREADY_DECIDED', message: 'Cannot cancel a decided request' }, { status: 409 });
    }
    if (gateReq.requested_by !== user.id && !user.isAdmin) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    await sb.from('visitor_gate_requests').update({ status: 'cancelled' }).eq('id', id);
    return Response.json({ ok: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
