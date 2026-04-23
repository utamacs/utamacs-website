import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('post_comments')
      .select('id, body, created_at, author_id, parent_id, profiles(full_name)')
      .eq('post_id', params.id!)
      .eq('is_hidden', false)
      .order('created_at', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as { body?: string; parent_id?: string };

    if (!body.body?.trim()) {
      return new Response(JSON.stringify({ error: 'body is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: post } = await sb
      .from('community_posts')
      .select('id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .single();

    if (!post) {
      return new Response(JSON.stringify({ error: 'Post not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('post_comments')
      .insert({
        post_id: params.id!,
        author_id: user.id,
        body: sanitizePlainText(body.body),
        parent_id: body.parent_id ?? null,
        is_hidden: false,
      })
      .select('id, body, created_at, author_id, parent_id, profiles(full_name)')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
