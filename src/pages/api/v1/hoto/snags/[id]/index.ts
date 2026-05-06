export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — snag item detail with linked files and comments
// Auth: snag.view
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'snag.view');

    const snagId = params.id!;
    const sb = getSupabaseServiceClient();

    const [snagRes, filesRes, commentsRes] = await Promise.all([
      sb.from('snag_items').select('*').eq('id', snagId).eq('society_id', SOCIETY_ID).single(),
      sb.from('governance_files')
        .select('id, name, file_type, file_size_bytes, github_path, uploaded_by, created_at')
        .eq('item_type', 'snag_item')
        .eq('item_id', snagId)
        .is('superseded_by', null)
        .order('created_at', { ascending: false }),
      sb.from('hoto_comments')
        .select('id, body, created_at, author_id, profiles!inner(full_name, portal_role, committee_title)')
        .eq('item_type', 'snag_item')
        .eq('item_id', snagId)
        .order('created_at', { ascending: false })
        .limit(50),
    ]);

    if (snagRes.error || !snagRes.data || (snagRes.data as any).deleted) {
      return Response.json({ error: 'NOT_FOUND', message: 'Snag item not found' }, { status: 404 });
    }

    return Response.json({
      snag: snagRes.data,
      files: filesRes.data ?? [],
      comments: (commentsRes.data ?? []).reverse(),
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — update snag metadata (auth: snag.create)
// Editable: category, subcategory, location, flat_number, description, severity,
//           ascenza_reference, builder_committed_date, notice_sent, responsible_user_id, video_url
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'snag.create');

    const snagId = params.id!;
    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('snag_items')
      .select('id, status, deleted')
      .eq('id', snagId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing || (existing as any).deleted) {
      return Response.json({ error: 'NOT_FOUND', message: 'Snag item not found' }, { status: 404 });
    }

    if ((existing as any).status === 'VERIFIED_CLOSED') {
      return Response.json({ error: 'CONFLICT', message: 'Cannot edit a verified-closed snag' }, { status: 409 });
    }

    const body = await request.json() as Record<string, unknown>;
    const allowed = [
      'category', 'subcategory', 'location', 'flat_number', 'description',
      'severity', 'ascenza_reference', 'builder_committed_date',
      'notice_sent', 'responsible_user_id', 'video_url',
    ];
    const updates: Record<string, unknown> = {};
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No updatable fields provided' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('snag_items')
      .update(updates)
      .eq('id', snagId)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'snag_items', resourceId: snagId,
      ip: extractClientIP(request),
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE — soft-delete a snag (auth: snag.delete, president only)
// Body: { deletion_reason }
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'snag.delete');

    const snagId = params.id!;
    const body = await request.json() as { deletion_reason?: string };

    if (!body.deletion_reason?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'deletion_reason is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('snag_items')
      .select('id, deleted')
      .eq('id', snagId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing || (existing as any).deleted) {
      return Response.json({ error: 'NOT_FOUND', message: 'Snag item not found' }, { status: 404 });
    }

    const { error } = await sb.from('snag_items').update({
      deleted: true,
      deleted_by: user.id,
      deleted_at: new Date().toISOString(),
      deletion_reason: body.deletion_reason.trim(),
    }).eq('id', snagId);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'DELETE',
        resource_type: 'snag_items',
        resource_id: snagId,
        new_values: { deleted: true, deletion_reason: body.deletion_reason.trim() },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'DELETE', resourceType: 'snag_items', resourceId: snagId,
        ip: extractClientIP(request),
        newValues: { deletion_reason: body.deletion_reason.trim() },
      }),
    ]);

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
