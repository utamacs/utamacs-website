import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list allocations (member sees own; exec/admin see all)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('parking_allocations')
      .select(`
        id, slot_id, unit_id, user_id, vehicle_number, vehicle_make,
        status, allocated_at, released_at, expires_at, notes,
        parking_slots(slot_number, slot_type, vehicle_type, level),
        units(unit_number, block),
        profiles(full_name)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('allocated_at', { ascending: false });

    if (user.role === 'member') {
      query = query.eq('user_id', user.id);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — allocate a slot to a unit/user (exec/admin only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only executives and admins can allocate parking slots' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      slot_id?: string; unit_id?: string; user_id?: string;
      vehicle_number?: string; vehicle_make?: string;
      expires_at?: string; notes?: string;
    };

    if (!body.slot_id || !body.unit_id || !body.user_id) {
      return new Response(JSON.stringify({ error: 'slot_id, unit_id, and user_id are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify slot exists and belongs to society
    const { data: slot } = await sb
      .from('parking_slots')
      .select('id, slot_number, is_active')
      .eq('id', body.slot_id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!slot || !(slot as any).is_active) {
      return new Response(JSON.stringify({ error: 'Parking slot not found or inactive' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Check for existing active allocation
    const { data: existing } = await sb
      .from('parking_allocations')
      .select('id, units(unit_number)')
      .eq('slot_id', body.slot_id)
      .eq('status', 'active')
      .maybeSingle();

    if (existing) {
      const e = existing as any;
      return new Response(JSON.stringify({
        error: `Slot ${(slot as any).slot_number} is already allocated to unit ${e.units?.unit_number ?? 'unknown'}. Release it first.`,
      }), { status: 409, headers: { 'Content-Type': 'application/json' } });
    }

    const { data, error } = await sb
      .from('parking_allocations')
      .insert({
        society_id: SOCIETY_ID,
        slot_id: body.slot_id,
        unit_id: body.unit_id,
        user_id: body.user_id,
        vehicle_number: body.vehicle_number ? sanitizePlainText(body.vehicle_number) : null,
        vehicle_make: body.vehicle_make ? sanitizePlainText(body.vehicle_make) : null,
        status: 'active',
        allocated_by: user.id,
        expires_at: body.expires_at ?? null,
        notes: body.notes ? sanitizePlainText(body.notes) : null,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Insert parking audit entry
    await sb.from('parking_audit').insert({
      society_id: SOCIETY_ID,
      slot_id: body.slot_id,
      allocation_id: (data as any).id,
      action: 'ALLOCATED',
      actor_id: user.id,
      unit_id: body.unit_id,
      notes: body.notes ?? null,
    });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'parking_allocations', resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { slot_id: body.slot_id, unit_id: body.unit_id },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
