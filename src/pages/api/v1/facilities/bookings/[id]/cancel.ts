import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: booking, error: fetchErr } = await sb
      .from('facility_bookings')
      .select('id, user_id, facility_id, status, start_time, cancellation_hours_free, deposit_paid, facilities(cancellation_hours_free, name)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !booking) {
      return new Response(JSON.stringify({ error: 'Booking not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const isOwner = (booking as any).user_id === user.id;
    const isMod = ['executive', 'admin'].includes(user.role);
    if (!isOwner && !isMod) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!['pending', 'confirmed'].includes((booking as any).status)) {
      return new Response(JSON.stringify({ error: `Cannot cancel a booking with status: ${(booking as any).status}` }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Determine if within free cancellation window
    const b = booking as any;
    const freeCancelHours = b.facilities?.cancellation_hours_free ?? 24;
    const hoursUntilStart = (new Date(b.start_time).getTime() - Date.now()) / 3600000;
    const depositRefundable = hoursUntilStart >= freeCancelHours;

    const body = await request.json().catch(() => ({})) as { reason?: string };

    const { data, error: updateErr } = await sb
      .from('facility_bookings')
      .update({
        status: 'cancelled',
        cancelled_at: new Date().toISOString(),
        cancellation_reason: body.reason ?? null,
        deposit_refunded: depositRefundable,
      })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // Promote first waitlisted booking for the same facility + date if applicable
    const bookingDate = new Date(b.start_time).toISOString().slice(0, 10);
    const { data: waitlisted } = await sb
      .from('facility_bookings')
      .select('id')
      .eq('facility_id', b.facility_id)
      .eq('society_id', SOCIETY_ID)
      .eq('status', 'waitlisted')
      .gte('booking_date', bookingDate)
      .lte('booking_date', bookingDate)
      .order('created_at', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (waitlisted) {
      await sb.from('facility_bookings').update({ status: 'confirmed' }).eq('id', waitlisted.id);
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'facility_bookings', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { status: 'cancelled', deposit_refunded: depositRefundable },
    });

    return new Response(JSON.stringify({
      booking: data,
      deposit_refunded: depositRefundable,
      message: depositRefundable
        ? 'Booking cancelled. Deposit will be refunded.'
        : `Booking cancelled. Cancellation was within ${freeCancelHours}h window — deposit forfeited.`,
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
