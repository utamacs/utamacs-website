export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list HOTO items this snag is linked to
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const snagId = params.id!;
    const sb = getSupabaseServiceClient();

    const { data: snag } = await sb
      .from('snag_items')
      .select('id')
      .eq('id', snagId)
      .eq('society_id', SOCIETY_ID)
      .eq('deleted', false)
      .single();
    if (!snag) return Response.json({ error: 'NOT_FOUND', message: 'Snag not found.' }, { status: 404 });

    const { data, error } = await sb
      .from('hoto_item_snag_links')
      .select(`
        id, notes, created_at,
        hoto_item_id,
        hoto_item:hoto_items!hoto_item_snag_links_hoto_item_id_fkey(
          id, title, status, priority, hoto_category
        )
      `)
      .eq('snag_item_id', snagId)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: true });

    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
