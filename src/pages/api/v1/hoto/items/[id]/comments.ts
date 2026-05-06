export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list comments for a HOTO item (paginated, oldest first)
// Auth: hoto.view feature required
// Query: before (cursor: created_at ISO string for pagination), limit (default 30, max 100)
export const GET: APIRoute = async ({ request, params, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.view');

    const itemId = params.id!;
    const limit  = Math.min(parseInt(url.searchParams.get('limit') ?? '30', 10) || 30, 100);
    const before = url.searchParams.get('before')?.trim() ?? '';

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('hoto_comments')
      .select(`
        id, content, is_pinned, created_at, edited_at, parent_comment_id,
        author_id,
        author:profiles!hoto_comments_author_id_fkey(full_name, portal_role, committee_title)
      `)
      .eq('item_type', 'hoto_item')
      .eq('item_id', itemId)
      .order('created_at', { ascending: true })
      .limit(limit);

    if (before) query = query.lt('created_at', before);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — add a comment to a HOTO item
// Auth: hoto.comment feature required
// Body: { content, parent_comment_id? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.comment');

    const itemId = params.id!;
    const body = await request.json() as { content?: string; parent_comment_id?: string };

    if (!body.content?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'content is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify the HOTO item exists in this society
    const { data: item } = await sb
      .from('hoto_items')
      .select('id')
      .eq('id', itemId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!item) {
      return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found' }, { status: 404 });
    }

    // Validate parent comment exists if provided
    if (body.parent_comment_id) {
      const { data: parent } = await sb
        .from('hoto_comments')
        .select('id')
        .eq('id', body.parent_comment_id)
        .eq('item_type', 'hoto_item')
        .eq('item_id', itemId)
        .single();

      if (!parent) {
        return Response.json({ error: 'NOT_FOUND', message: 'Parent comment not found' }, { status: 404 });
      }
    }

    const commentId = `CMT-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;

    const { data, error } = await sb
      .from('hoto_comments')
      .insert({
        id: commentId,
        item_type: 'hoto_item',
        item_id: itemId,
        author_id: user.id,
        content: body.content.trim(),
        parent_comment_id: body.parent_comment_id ?? null,
      })
      .select('id, content, is_pinned, created_at, author_id, parent_comment_id')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
