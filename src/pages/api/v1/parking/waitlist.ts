export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_SLOT_TYPES = ['covered', 'open', 'basement', 'visitor', 'any'] as const;
const VALID_VEHICLE_TYPES = ['car', 'bike', 'cycle', 'ev', 'any'] as const;

// GET — list waitlist entries (member sees own; exec/admin see all)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('parking_waitlist')
      .select(`
        id, unit_id, user_id, slot_type, vehicle_type,
        status, requested_at, offered_at, offered_slot_id, notes,
        units(unit_number, block),
        profiles(full_name),
        parking_slots(slot_number, slot_type, vehicle_type, level)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('requested_at', { ascending: true });

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

// POST — join the waitlist
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const body = await request.json() as {
      unit_id?: string; slot_type?: string; vehicle_type?: string; notes?: string;
    };

    if (!body.unit_id) {
      return new Response(JSON.stringify({ error: 'unit_id is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (body.slot_type && !VALID_SLOT_TYPES.includes(body.slot_type as typeof VALID_SLOT_TYPES[number])) {
      return new Response(JSON.stringify({ error: `slot_type must be one of: ${VALID_SLOT_TYPES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (body.vehicle_type && !VALID_VEHICLE_TYPES.includes(body.vehicle_type as typeof VALID_VEHICLE_TYPES[number])) {
      return new Response(JSON.stringify({ error: `vehicle_type must be one of: ${VALID_VEHICLE_TYPES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Check if user already has an active allocation
    const { data: existingAlloc } = await sb
      .from('parking_allocations')
      .select('id, parking_slots(slot_number)')
      .eq('user_id', user.id)
      .eq('society_id', SOCIETY_ID)
      .eq('status', 'active')
      .maybeSingle();

    if (existingAlloc) {
      const slotNum = (existingAlloc as any).parking_slots?.slot_number ?? 'unknown';
      return new Response(JSON.stringify({
        error: `You already have an active parking allocation (Slot ${slotNum}). Release it before joining the waitlist.`,
      }), { status: 409, headers: { 'Content-Type': 'application/json' } });
    }

    // Check if already on waitlist
    const { data: existingWait } = await sb
      .from('parking_waitlist')
      .select('id, status')
      .eq('user_id', user.id)
      .eq('society_id', SOCIETY_ID)
      .in('status', ['waiting', 'offered'])
      .maybeSingle();

    if (existingWait) {
      return new Response(JSON.stringify({
        error: `You are already on the waitlist with status '${(existingWait as any).status}'.`,
      }), { status: 409, headers: { 'Content-Type': 'application/json' } });
    }

    const { data, error } = await sb
      .from('parking_waitlist')
      .insert({
        society_id: SOCIETY_ID,
        unit_id: body.unit_id,
        user_id: user.id,
        slot_type: body.slot_type ?? 'any',
        vehicle_type: body.vehicle_type ?? 'any',
        status: 'waiting',
        notes: body.notes ? sanitizePlainText(body.notes) : null,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return new Response(JSON.stringify({ error: 'You are already on the waitlist' }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    // parking_audit requires a valid slot_id FK; waitlist entries have no slot yet — skip it

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'parking_waitlist', resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { slot_type: body.slot_type ?? 'any', vehicle_type: body.vehicle_type ?? 'any' },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE — withdraw from waitlist
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const waitlistId = url.searchParams.get('id');
    if (!waitlistId) {
      return new Response(JSON.stringify({ error: 'id query parameter is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data: entry } = await sb
      .from('parking_waitlist')
      .select('id, user_id, status')
      .eq('id', waitlistId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!entry) {
      return new Response(JSON.stringify({ error: 'Waitlist entry not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Member can only withdraw own entry; exec/admin can withdraw any
    if (user.role === 'member' && (entry as any).user_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (['allocated', 'withdrawn'].includes((entry as any).status)) {
      return new Response(JSON.stringify({ error: `Cannot withdraw entry with status '${(entry as any).status}'` }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { error } = await sb
      .from('parking_waitlist')
      .update({ status: 'withdrawn' })
      .eq('id', waitlistId);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'parking_waitlist', resourceId: waitlistId,
      ip: extractClientIP(request),
      oldValues: { status: (entry as any).status }, newValues: { status: 'withdrawn' },
    });

    return new Response(JSON.stringify({ message: 'Withdrawn from waitlist' }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
