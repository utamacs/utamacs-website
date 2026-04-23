import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText, sanitizeHTML } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_CATEGORIES = ['General', 'Help', 'Lost_Found', 'Recommendation', 'Alert'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const category = url.searchParams.get('category');
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '20'), 50);
    const offset = parseInt(url.searchParams.get('offset') ?? '0');

    let query = sb
      .from('community_posts')
      .select(`
        id, title, body, category, is_pinned, created_at, updated_at,
        author_id, profiles(full_name, avatar_storage_key), units(unit_number),
        post_reactions(reaction_type)
      `)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .eq('is_moderated', false)
      .order('is_pinned', { ascending: false })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (category && VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      query = query.eq('category', category);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const posts = (data ?? []).map((p: any) => ({
      ...p,
      like_count: (p.post_reactions ?? []).filter((r: any) => r.reaction_type === 'like').length,
      helpful_count: (p.post_reactions ?? []).filter((r: any) => r.reaction_type === 'helpful').length,
      post_reactions: undefined,
    }));

    return new Response(JSON.stringify(posts), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);

    const body = await request.json() as {
      title?: string; body?: string; category?: string; unit_id?: string;
    };

    if (!body.title?.trim() || !body.body?.trim()) {
      return new Response(JSON.stringify({ error: 'title and body are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!VALID_CATEGORIES.includes((body.category ?? '') as typeof VALID_CATEGORIES[number])) {
      return new Response(JSON.stringify({ error: `category must be one of: ${VALID_CATEGORIES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    let unit_id = body.unit_id ?? null;
    if (!unit_id) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      unit_id = profile?.unit_id ?? null;
    }

    const { data, error } = await sb
      .from('community_posts')
      .insert({
        society_id: SOCIETY_ID,
        author_id: user.id,
        unit_id,
        title: sanitizePlainText(body.title),
        body: sanitizeHTML(body.body),
        category: body.category,
        is_pinned: false,
        is_published: true,
        is_moderated: false,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'community_posts', resourceId: data.id,
      ip: extractClientIP(request), newValues: { category: data.category },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
