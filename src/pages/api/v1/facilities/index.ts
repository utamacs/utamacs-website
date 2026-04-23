export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('facilities')
      .select('id, name, description, capacity, amenities, booking_fee, deposit_amount, is_active, advance_booking_days, cancellation_hours_free')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('name');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
