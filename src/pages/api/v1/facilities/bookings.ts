import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('facility_bookings')
      .select('id, facility_id, user_id, unit_id, booking_date, start_time, end_time, attendees_count, purpose, status, fee_charged, deposit_paid, created_at, facilities(name)')
      .eq('society_id', SOCIETY_ID)
      .order('booking_date', { ascending: false });

    if (user.role === 'member') query = query.eq('user_id', user.id);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'bookings', 'create',
    );

    const body = await request.json() as Record<string, unknown>;
    const { facility_id, booking_date, start_time, end_time, attendees_count, purpose, unit_id } = body;

    if (!facility_id || !booking_date || !start_time || !end_time || !unit_id) {
      return new Response(JSON.stringify({ error: 'facility_id, booking_date, start_time, end_time, unit_id are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Check for conflicts
    const { data: conflicts } = await sb
      .from('facility_bookings')
      .select('id')
      .eq('facility_id', facility_id as string)
      .eq('booking_date', booking_date as string)
      .in('status', ['pending', 'confirmed'])
      .lt('start_time', end_time as string)
      .gt('end_time', start_time as string);

    if (conflicts && conflicts.length > 0) {
      return new Response(JSON.stringify({ error: 'The requested slot is not available' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('facility_bookings')
      .insert({
        society_id: SOCIETY_ID,
        facility_id,
        user_id: user.id,
        unit_id,
        booking_date,
        start_time,
        end_time,
        attendees_count: attendees_count ?? 1,
        purpose: purpose ? sanitizePlainText(String(purpose)) : null,
        status: 'pending',
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
