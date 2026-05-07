export const prerender = false;
// Public endpoint — returns unit list for self-registration form (no personal data)
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('units')
      .select('id, unit_number, block, floor')
      .eq('society_id', SOCIETY_ID)
      .order('block')
      .order('unit_number');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
