import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PUT — mark delivery as collected
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: delivery } = await sb
      .from('delivery_logs')
      .select('id, unit_id, collected_at')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!delivery) {
      return new Response(JSON.stringify({ error: 'Delivery not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((delivery as any).collected_at) {
      return new Response(JSON.stringify({ error: 'Delivery already marked as collected' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('delivery_logs')
      .update({ collected_at: new Date().toISOString(), collected_by: user.id })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
