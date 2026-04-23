export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('community_posts')
      .select(`
        id, title, body, category, is_pinned, created_at, updated_at, author_id,
        profiles(full_name, avatar_storage_key), units(unit_number),
        post_reactions(reaction_type, user_id)
      `)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .single();

    if (error || !data) {
      return new Response(JSON.stringify({ error: 'Post not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const reactions = (data as any).post_reactions ?? [];
    const result = {
      ...(data as any),
      like_count: reactions.filter((r: any) => r.reaction_type === 'like').length,
      helpful_count: reactions.filter((r: any) => r.reaction_type === 'helpful').length,
      user_reaction: reactions.find((r: any) => r.user_id === user.id)?.reaction_type ?? null,
      post_reactions: undefined,
    };

    return new Response(JSON.stringify(result), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: post } = await sb
      .from('community_posts')
      .select('author_id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!post) {
      return new Response(JSON.stringify({ error: 'Post not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const isOwner = post.author_id === user.id;
    const isMod = ['executive', 'admin'].includes(user.role);
    if (!isOwner && !isMod) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (isMod && !isOwner) {
      await sb.from('community_posts').update({ is_moderated: true, moderated_by: user.id }).eq('id', params.id!);
    } else {
      await sb.from('community_posts').update({ is_published: false }).eq('id', params.id!);
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DELETE', resourceType: 'community_posts', resourceId: params.id!,
      ip: extractClientIP(request),
    });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
