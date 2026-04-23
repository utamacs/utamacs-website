import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const unreadOnly = url.searchParams.get('unread') === 'true';
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '30'), 50);

    let query = sb
      .from('notifications')
      .select('id, title, body, type, reference_table, reference_id, is_read, read_at, created_at')
      .eq('user_id', user.id)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (unreadOnly) query = query.eq('is_read', false);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
