export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list snags linked to this HOTO item
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const hotoItemId = params.id!;
    const sb = getSupabaseServiceClient();

    const { data: hotoItem } = await sb
      .from('hoto_items')
      .select('id')
      .eq('id', hotoItemId)
      .eq('society_id', SOCIETY_ID)
      .single();
    if (!hotoItem) return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found.' }, { status: 404 });

    const { data, error } = await sb
      .from('hoto_item_snag_links')
      .select(`
        id, notes, created_at,
        snag_item_id,
        snag:snag_items!hoto_item_snag_links_snag_item_id_fkey(
          id, category, subcategory, location, status, severity, description
        ),
        linked_by_profile:profiles!hoto_item_snag_links_linked_by_fkey(full_name)
      `)
      .eq('hoto_item_id', hotoItemId)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: true });

    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — link a snag to this HOTO item (exec only)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN', message: 'Exec access required.' }, { status: 403 });

    const hotoItemId = params.id!;
    const body = await request.json() as { snag_id?: string; notes?: string };

    if (!body.snag_id?.trim() || !UUID_RE.test(body.snag_id.trim())) {
      return Response.json({ error: 'VALIDATION', message: 'Valid snag_id UUID is required.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const [{ data: hotoItem }, { data: snagItem }] = await Promise.all([
      sb.from('hoto_items').select('id').eq('id', hotoItemId).eq('society_id', SOCIETY_ID).single(),
      sb.from('snag_items').select('id').eq('id', body.snag_id.trim()).eq('society_id', SOCIETY_ID).eq('deleted', false).single(),
    ]);

    if (!hotoItem) return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found.' }, { status: 404 });
    if (!snagItem) return Response.json({ error: 'NOT_FOUND', message: 'Snag not found.' }, { status: 404 });

    const { data, error } = await sb
      .from('hoto_item_snag_links')
      .insert({
        society_id:   SOCIETY_ID,
        hoto_item_id: hotoItemId,
        snag_item_id: body.snag_id.trim(),
        linked_by:    user.id,
        notes:        body.notes?.trim() || null,
      })
      .select(`
        id, notes, created_at, snag_item_id,
        snag:snag_items!hoto_item_snag_links_snag_item_id_fkey(
          id, category, subcategory, location, status, severity, description
        )
      `)
      .single();

    if (error) {
      if (error.code === '23505') {
        return Response.json({ error: 'CONFLICT', message: 'Snag is already linked to this HOTO item.' }, { status: 409 });
      }
      throw error;
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'hoto_item_snag_links', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { hoto_item_id: hotoItemId, snag_item_id: body.snag_id.trim() },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE — unlink a snag from this HOTO item (exec only)
// Query param: ?snag_id=<uuid>
export const DELETE: APIRoute = async ({ request, params, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN', message: 'Exec access required.' }, { status: 403 });

    const hotoItemId = params.id!;
    const snagId = url.searchParams.get('snag_id')?.trim() ?? '';

    if (!snagId || !UUID_RE.test(snagId)) {
      return Response.json({ error: 'VALIDATION', message: 'Valid snag_id query parameter is required.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: link } = await sb
      .from('hoto_item_snag_links')
      .select('id')
      .eq('hoto_item_id', hotoItemId)
      .eq('snag_item_id', snagId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!link) return Response.json({ error: 'NOT_FOUND', message: 'Link not found.' }, { status: 404 });

    const { error } = await sb
      .from('hoto_item_snag_links')
      .delete()
      .eq('id', link.id);

    if (error) throw error;

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DELETE', resourceType: 'hoto_item_snag_links', resourceId: link.id,
      ip: extractClientIP(request),
      oldValues: { hoto_item_id: hotoItemId, snag_item_id: snagId },
    });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
