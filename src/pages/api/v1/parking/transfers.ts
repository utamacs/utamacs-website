export const prerender = false;
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive', 'admin'].includes(user.role);

    let query = sb
      .from('parking_slot_transfers')
      .select(`
        id, reason, status, approved_at, rejection_note, created_at,
        parking_slots(slot_number),
        from_unit:from_unit_id(unit_number),
        to_unit:to_unit_id(unit_number)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (!isPrivileged) {
      query = (query as any).eq('requested_by', user.id);
    }

    const { data, error } = await query;
    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as {
      slot_id?: string;
      to_unit_id?: string;
      reason?: string;
    };

    if (!body.slot_id || !body.to_unit_id) {
      return Response.json({ error: 'MISSING_FIELDS', message: 'slot_id and to_unit_id are required.' }, { status: 400 });
    }
    if (!UUID_RE.test(body.slot_id) || !UUID_RE.test(body.to_unit_id)) {
      return Response.json({ error: 'INVALID_ID' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Get current active allocation to determine from_unit_id
    const { data: alloc } = await sb
      .from('parking_allocations')
      .select('unit_id')
      .eq('slot_id', body.slot_id)
      .eq('status', 'active')
      .maybeSingle();

    const from_unit_id = (alloc as any)?.unit_id ?? null;

    const reason = body.reason?.trim().slice(0, 500) || null;

    const { data, error } = await sb
      .from('parking_slot_transfers')
      .insert({
        society_id: SOCIETY_ID,
        slot_id: body.slot_id,
        from_unit_id,
        to_unit_id: body.to_unit_id,
        reason,
        requested_by: user.id,
      })
      .select()
      .single();

    if (error) throw error;

    await writeAuditLog({
      userId: user.id,
      societyId: SOCIETY_ID,
      action: 'CREATE',
      resourceType: 'parking_slot_transfer',
      resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { slot_id: body.slot_id, to_unit_id: body.to_unit_id },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
