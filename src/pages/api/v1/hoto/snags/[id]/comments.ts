export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list comments for a snag item (oldest first)
export const GET: APIRoute = async ({ request, params, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'hoto.view');

    const snagId = params.id!;
    const limit  = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 100);
    const before = url.searchParams.get('before')?.trim() ?? '';

    const sb = getSupabaseServiceClient();

    // Verify snag belongs to this society
    const { data: snag } = await sb
      .from('snag_items')
      .select('id')
      .eq('id', snagId)
      .eq('society_id', SOCIETY_ID)
      .eq('deleted', false)
      .single();
    if (!snag) return Response.json({ error: 'NOT_FOUND', message: 'Snag not found.' }, { status: 404 });

    let query = sb
      .from('hoto_comments')
      .select(`
        id, content, is_pinned, created_at, edited_at, parent_comment_id,
        author_id,
        author:profiles!hoto_comments_author_id_fkey(full_name, portal_role, committee_title)
      `)
      .eq('item_type', 'snag_item')
      .eq('item_id', snagId)
      .order('created_at', { ascending: true })
      .limit(limit);

    if (before) query = query.lt('created_at', before);

    const { data, error } = await query;
    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — add a comment to a snag item
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'hoto.comment');

    const snagId = params.id!;
    const body = await request.json() as { body?: string; content?: string; parent_comment_id?: string };
    const content = (body.content ?? body.body ?? '').trim();

    if (!content) {
      return Response.json({ error: 'VALIDATION', message: 'Comment body is required.' }, { status: 400 });
    }
    if (content.length > 4000) {
      return Response.json({ error: 'VALIDATION', message: 'Comment must be under 4000 characters.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: snag } = await sb
      .from('snag_items')
      .select('id')
      .eq('id', snagId)
      .eq('society_id', SOCIETY_ID)
      .eq('deleted', false)
      .single();
    if (!snag) return Response.json({ error: 'NOT_FOUND', message: 'Snag not found.' }, { status: 404 });

    if (body.parent_comment_id) {
      const { data: parent } = await sb
        .from('hoto_comments')
        .select('id')
        .eq('id', body.parent_comment_id)
        .eq('item_type', 'snag_item')
        .eq('item_id', snagId)
        .single();
      if (!parent) {
        return Response.json({ error: 'NOT_FOUND', message: 'Parent comment not found.' }, { status: 404 });
      }
    }

    const commentId = `SCMT-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;

    const { data, error } = await sb
      .from('hoto_comments')
      .insert({
        id:                commentId,
        item_type:         'snag_item',
        item_id:           snagId,
        author_id:         user.id,
        content,
        parent_comment_id: body.parent_comment_id ?? null,
      })
      .select(`
        id, content, is_pinned, created_at, author_id,
        author:profiles!hoto_comments_author_id_fkey(full_name, portal_role)
      `)
      .single();

    if (error) throw error;
    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
