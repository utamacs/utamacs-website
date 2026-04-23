import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await validateJWT(request);
    const unitNumber = url.searchParams.get('unit_number');
    if (!unitNumber) {
      return new Response(JSON.stringify({ error: 'unit_number is required' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }
    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('units').select('id, unit_number, block')
      .eq('society_id', SOCIETY_ID)
      .ilike('unit_number', unitNumber.trim())
      .single();
    if (error || !data) {
      return new Response(JSON.stringify({ error: 'Unit not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
    }
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
