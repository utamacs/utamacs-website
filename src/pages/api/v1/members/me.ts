import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('profiles')
      .select('id, full_name, residency_type, move_in_date, avatar_storage_key, is_active, consent_version, consent_at, units(unit_number, block, floor)')
      .eq('id', user.id)
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PUT: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as { full_name?: string; residency_type?: string };
    const updates: Record<string, unknown> = {};
    if (body.full_name) updates['full_name'] = sanitizePlainText(body.full_name);
    if (body.residency_type) updates['residency_type'] = body.residency_type;
    updates['updated_at'] = new Date().toISOString();

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('profiles')
      .update(updates)
      .eq('id', user.id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
