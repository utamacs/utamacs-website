export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_SLOT_TYPES = ['covered', 'open', 'basement', 'visitor'] as const;
const VALID_VEHICLE_TYPES = ['car', 'bike', 'cycle', 'ev', 'any'] as const;

// GET — list all parking slots with current allocation status
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const slotType = url.searchParams.get('slot_type');
    const vehicleType = url.searchParams.get('vehicle_type');
    const available = url.searchParams.get('available');

    let query = sb
      .from('parking_slots')
      .select(`
        id, slot_number, slot_type, vehicle_type, level, is_active,
        monthly_charge, notes,
        parking_allocations(id, unit_id, user_id, vehicle_number, vehicle_make, status, allocated_at, expires_at, units(unit_number))
      `)
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('slot_number');

    if (slotType) query = query.eq('slot_type', slotType);
    if (vehicleType) query = query.eq('vehicle_type', vehicleType);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Enrich: mark active allocation
    const slots = (data ?? []).map((s: any) => {
      const activeAlloc = (s.parking_allocations ?? []).find((a: any) => a.status === 'active') ?? null;
      return {
        ...s,
        is_available: !activeAlloc,
        active_allocation: activeAlloc,
        parking_allocations: undefined, // strip raw array
      };
    }).filter((s: any) => available === 'true' ? s.is_available : true);

    return new Response(JSON.stringify(slots), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create a new parking slot (exec/admin only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      slot_number?: string; slot_type?: string; vehicle_type?: string;
      level?: number; monthly_charge?: number; notes?: string;
    };

    if (!body.slot_number?.trim()) {
      return new Response(JSON.stringify({ error: 'slot_number is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (body.slot_type && !VALID_SLOT_TYPES.includes(body.slot_type as typeof VALID_SLOT_TYPES[number])) {
      return new Response(JSON.stringify({ error: `slot_type must be one of: ${VALID_SLOT_TYPES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('parking_slots')
      .insert({
        society_id: SOCIETY_ID,
        slot_number: sanitizePlainText(body.slot_number.trim()),
        slot_type: body.slot_type ?? 'open',
        vehicle_type: body.vehicle_type ?? 'car',
        level: body.level ?? 0,
        monthly_charge: body.monthly_charge ?? 0,
        notes: body.notes ? sanitizePlainText(body.notes) : null,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return new Response(JSON.stringify({ error: 'Slot number already exists' }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'parking_slots', resourceId: data.id,
      ip: extractClientIP(request), newValues: { slot_number: body.slot_number, slot_type: body.slot_type },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
