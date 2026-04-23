export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_REACTIONS = ['like', 'helpful'] as const;

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as { reaction_type?: string };

    if (!VALID_REACTIONS.includes((body.reaction_type ?? '') as typeof VALID_REACTIONS[number])) {
      return new Response(JSON.stringify({ error: 'reaction_type must be like or helpful' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: post } = await sb
      .from('community_posts')
      .select('id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!post) {
      return new Response(JSON.stringify({ error: 'Post not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data: existing } = await sb
      .from('post_reactions')
      .select('reaction_type')
      .eq('post_id', params.id!)
      .eq('user_id', user.id)
      .single();

    if (existing?.reaction_type === body.reaction_type) {
      // Toggle off — remove reaction
      await sb.from('post_reactions').delete().eq('post_id', params.id!).eq('user_id', user.id);
      return new Response(JSON.stringify({ action: 'removed' }), { headers: { 'Content-Type': 'application/json' } });
    }

    // Upsert reaction
    const { error } = await sb.from('post_reactions').upsert({
      post_id: params.id!,
      user_id: user.id,
      reaction_type: body.reaction_type,
    }, { onConflict: 'post_id,user_id' });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ action: 'added', reaction_type: body.reaction_type }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
