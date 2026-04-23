import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['security_guard','executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('visitor_logs')
      .update({ exit_time: new Date().toISOString() })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .is('exit_time', null)
      .select()
      .single();

    if (error || !data) {
      return new Response(JSON.stringify({ error: 'Log not found or exit already recorded' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
