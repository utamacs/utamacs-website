export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await validateJWT(request);
    const category = url.searchParams.get('category')?.trim() ?? '';

    const sb = getSupabaseServiceClient();
    let query = sb
      .from('complaint_sub_categories')
      .select('id, category, sub_category, sort_order')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('sort_order');

    if (category) query = query.eq('category', category);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
