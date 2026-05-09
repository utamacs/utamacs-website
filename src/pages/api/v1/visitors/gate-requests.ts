export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/visitors/gate-requests?status=pending
// Guards see all pending for the society; residents see their unit's pending requests only.
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const url = new URL(request.url);
    const status = url.searchParams.get('status') ?? 'pending';

    const isGuard = (user as { role?: string }).role === 'security_guard';
    const isPrivileged = user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');

    const sb = getSupabaseServiceClient();
    const now = new Date().toISOString();

    let query = sb
      .from('visitor_gate_requests')
      .select('id, visitor_name, visitor_type, vehicle_number, purpose, status, created_at, expires_at, decided_at, decision_note, host_unit_id, requested_by, approved_by, units(unit_number, block), profiles!requested_by(display_name), profiles!approved_by(display_name)')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(50);

    if (status !== 'all') {
      query = query.eq('status', status);
    }

    // Guards and execs see all; residents see only their unit
    if (!isGuard && !isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      if (!profile?.unit_id) {
        return Response.json([]);
      }
      query = query.eq('host_unit_id', profile.unit_id);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Mark expired ones
    const rows = (data ?? []).map(r => ({
      ...r,
      is_expired: r.status === 'pending' && new Date(r.expires_at) < new Date(),
    }));

    return Response.json(rows);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/visitors/gate-requests — guard creates an approval request
// Body: { visitor_name, visitor_type?, vehicle_number?, purpose?, host_unit_id }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    // Only guards and exec can create gate requests
    const isGuard = (user as { role?: string }).role === 'security_guard';
    const isPrivileged = user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
    if (!isGuard && !isPrivileged) {
      return Response.json({ error: 'FORBIDDEN', message: 'Only security guards can submit gate requests' }, { status: 403 });
    }

    const body = await request.json() as {
      visitor_name?: string;
      visitor_type?: string;
      vehicle_number?: string;
      purpose?: string;
      host_unit_id?: string;
    };

    if (!body.visitor_name?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'visitor_name is required' }, { status: 400 });
    }
    if (!body.host_unit_id || !UUID_RE.test(body.host_unit_id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'valid host_unit_id is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify unit belongs to this society
    const { data: unit } = await sb.from('units').select('id').eq('id', body.host_unit_id).eq('society_id', SOCIETY_ID).single();
    if (!unit) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Unit not found' }, { status: 400 });
    }

    const rules = await getRules(sb, SOCIETY_ID, ['GATE_APPROVAL_TIMEOUT_MINS']);
    const timeoutMins = ruleInt(rules, 'GATE_APPROVAL_TIMEOUT_MINS', 10);
    const expiresAt = new Date(Date.now() + timeoutMins * 60000).toISOString();

    const { data: gateReq, error: insertErr } = await sb
      .from('visitor_gate_requests')
      .insert({
        society_id:    SOCIETY_ID,
        host_unit_id:  body.host_unit_id,
        visitor_name:  body.visitor_name.trim().slice(0, 100),
        visitor_type:  body.visitor_type?.trim() ?? null,
        vehicle_number: body.vehicle_number?.trim().slice(0, 20) ?? null,
        purpose:       body.purpose?.trim().slice(0, 200) ?? null,
        requested_by:  user.id,
        expires_at:    expiresAt,
      })
      .select('id, visitor_name, expires_at, host_unit_id, units(unit_number, block)')
      .single();

    if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'visitor_gate_request', resourceId: gateReq!.id,
      ip: extractClientIP(request),
      newValues: { visitor_name: body.visitor_name, host_unit_id: body.host_unit_id },
    });

    return Response.json(gateReq, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
