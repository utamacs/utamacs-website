import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PUT — release an active allocation (active → released)
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only executives and admins can release parking allocations' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const body = await request.json().catch(() => ({})) as { notes?: string };

    // Fetch existing allocation
    const { data: allocation } = await sb
      .from('parking_allocations')
      .select('id, slot_id, unit_id, user_id, status, parking_slots(slot_number)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!allocation) {
      return new Response(JSON.stringify({ error: 'Allocation not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((allocation as any).status !== 'active') {
      return new Response(JSON.stringify({ error: `Cannot release allocation with status '${(allocation as any).status}'. Only active allocations can be released.` }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('parking_allocations')
      .update({
        status: 'released',
        released_at: new Date().toISOString(),
        released_by: user.id,
        notes: body.notes ? sanitizePlainText(body.notes) : (allocation as any).notes,
        updated_at: new Date().toISOString(),
      })
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Insert parking audit entry
    await sb.from('parking_audit').insert({
      society_id: SOCIETY_ID,
      slot_id: (allocation as any).slot_id,
      allocation_id: params.id!,
      action: 'RELEASED',
      actor_id: user.id,
      unit_id: (allocation as any).unit_id,
      notes: body.notes ?? null,
    });

    // Check waitlist — offer slot to next waiting entry matching slot type
    const { data: slotInfo } = await sb
      .from('parking_slots')
      .select('slot_type, vehicle_type')
      .eq('id', (allocation as any).slot_id)
      .single();

    let waitlistOffered = null;
    if (slotInfo) {
      const { data: nextWaiting } = await sb
        .from('parking_waitlist')
        .select('id, user_id, unit_id')
        .eq('society_id', SOCIETY_ID)
        .eq('status', 'waiting')
        .or(`slot_type.eq.any,slot_type.eq.${(slotInfo as any).slot_type}`)
        .or(`vehicle_type.eq.any,vehicle_type.eq.${(slotInfo as any).vehicle_type}`)
        .order('requested_at', { ascending: true })
        .limit(1)
        .maybeSingle();

      if (nextWaiting) {
        await sb
          .from('parking_waitlist')
          .update({
            status: 'offered',
            offered_at: new Date().toISOString(),
            offered_slot_id: (allocation as any).slot_id,
          })
          .eq('id', (nextWaiting as any).id);

        // Notify the waitlisted user
        await sb.from('notifications').insert({
          society_id: SOCIETY_ID,
          user_id: (nextWaiting as any).user_id,
          title: 'Parking Slot Available',
          body: `Slot ${(slotInfo as any) ? ((allocation as any).parking_slots as any)?.slot_number ?? 'A parking slot' : 'A parking slot'} is now available for you. Please contact the management to confirm your allocation.`,
          type: 'system',
          reference_table: 'parking_allocations',
          reference_id: params.id!,
          channel: 'in_app',
          status: 'pending',
        });

        await sb.from('parking_audit').insert({
          society_id: SOCIETY_ID,
          slot_id: (allocation as any).slot_id,
          allocation_id: null,
          action: 'WAITLIST_OFFERED',
          actor_id: user.id,
          unit_id: (nextWaiting as any).unit_id,
          notes: 'Auto-offered after release',
        });

        waitlistOffered = { waitlist_id: (nextWaiting as any).id, unit_id: (nextWaiting as any).unit_id };
      }
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'parking_allocations', resourceId: params.id!,
      ip: extractClientIP(request),
      oldValues: { status: 'active' }, newValues: { status: 'released' },
    });

    return new Response(JSON.stringify({ allocation: data, waitlist_offered: waitlistOffered }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
