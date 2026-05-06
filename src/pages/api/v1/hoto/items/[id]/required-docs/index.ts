export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list required documents for a HOTO item
// Auth: hoto.view feature required
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.view');

    const itemId = params.id!;
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('hoto_required_docs')
      .select('*')
      .eq('hoto_item_id', itemId)
      .order('created_at');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — add a required document to the checklist for a HOTO item
// Auth: hoto.create feature required
// Body: { doc_name, required? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.create');

    const itemId = params.id!;
    const body = await request.json() as { doc_name?: string; required?: boolean };

    if (!body.doc_name?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'doc_name is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify item exists in this society
    const { data: item } = await sb
      .from('hoto_items')
      .select('id')
      .eq('id', itemId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!item) {
      return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found' }, { status: 404 });
    }

    const { data, error } = await sb
      .from('hoto_required_docs')
      .insert({
        hoto_item_id: itemId,
        doc_name: body.doc_name.trim(),
        required: body.required ?? true,
        uploaded: false,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
