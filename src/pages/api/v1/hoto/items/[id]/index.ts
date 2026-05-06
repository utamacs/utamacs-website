export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_PRIORITIES = ['LOW','MEDIUM','HIGH','CRITICAL'] as const;

// GET — HOTO item detail with required docs, files, and recent comments
// Auth: hoto.view feature required
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.view');

    const itemId = params.id!;
    const sb = getSupabaseServiceClient();

    const [itemResult, docsResult, filesResult, commentsResult] = await Promise.all([
      sb.from('hoto_items')
        .select('*')
        .eq('id', itemId)
        .eq('society_id', SOCIETY_ID)
        .single(),

      sb.from('hoto_required_docs')
        .select('*')
        .eq('hoto_item_id', itemId)
        .order('created_at'),

      sb.from('governance_files')
        .select('id, name, file_type, file_size_bytes, github_path, uploaded_at, uploaded_by, is_confidential, description')
        .eq('item_type', 'hoto_item')
        .eq('item_id', itemId)
        .is('superseded_by', null)
        .order('uploaded_at', { ascending: false }),

      sb.from('hoto_comments')
        .select('id, content, author_id, is_pinned, created_at, edited_at, parent_comment_id, profiles!hoto_comments_author_id_fkey(full_name, portal_role)')
        .eq('item_type', 'hoto_item')
        .eq('item_id', itemId)
        .order('created_at', { ascending: false })
        .limit(30),
    ]);

    if (itemResult.error || !itemResult.data) {
      return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found' }, { status: 404 });
    }

    const itemRow = itemResult.data as any;

    // Resolve approver names from profiles
    const approverIds = [itemRow.president_approved_by, itemRow.secretary_approved_by].filter(Boolean);
    let approverNames: Record<string, string> = {};
    if (approverIds.length) {
      const { data: approverProfiles } = await sb.from('profiles').select('id, full_name').in('id', approverIds);
      for (const p of approverProfiles ?? []) approverNames[(p as any).id] = (p as any).full_name;
    }

    return Response.json({
      item: {
        ...itemRow,
        president_approved_by_name: itemRow.president_approved_by ? (approverNames[itemRow.president_approved_by] ?? null) : null,
        secretary_approved_by_name: itemRow.secretary_approved_by ? (approverNames[itemRow.secretary_approved_by] ?? null) : null,
      },
      required_docs: docsResult.data ?? [],
      files: filesResult.data ?? [],
      comments: (commentsResult.data ?? []).reverse(),
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — update HOTO item metadata (not status — use /advance for that)
// Auth: hoto.create feature required
// Body: { title?, description?, builder_commitment?, builder_contact?, priority?,
//         deadline?, builder_sla_date?, responsible_role?, responsible_user_id?,
//         rera_escalation_eligible?, governance_notes? }
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.create');

    const itemId = params.id!;
    const sb = getSupabaseServiceClient();

    // Verify item exists and belongs to this society
    const { data: existing, error: fetchErr } = await sb
      .from('hoto_items')
      .select('id, title, priority')
      .eq('id', itemId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found' }, { status: 404 });
    }

    const body = await request.json() as {
      title?: string;
      description?: string;
      builder_commitment?: string;
      builder_contact?: string;
      priority?: string;
      deadline?: string | null;
      builder_sla_date?: string | null;
      responsible_role?: string | null;
      responsible_user_id?: string | null;
      rera_escalation_eligible?: boolean;
      governance_notes?: string;
    };

    if (body.priority && !VALID_PRIORITIES.includes(body.priority as typeof VALID_PRIORITIES[number])) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: `priority must be one of: ${VALID_PRIORITIES.join(', ')}`,
      }, { status: 400 });
    }

    // Build update object from only provided fields
    const updates: Record<string, unknown> = {};
    if (body.title !== undefined) updates.title = body.title.trim();
    if (body.description !== undefined) updates.description = body.description?.trim() ?? null;
    if (body.builder_commitment !== undefined) updates.builder_commitment = body.builder_commitment?.trim() ?? null;
    if (body.builder_contact !== undefined) updates.builder_contact = body.builder_contact?.trim() ?? null;
    if (body.priority !== undefined) updates.priority = body.priority;
    if (body.deadline !== undefined) updates.deadline = body.deadline ?? null;
    if (body.builder_sla_date !== undefined) updates.builder_sla_date = body.builder_sla_date ?? null;
    if (body.responsible_role !== undefined) updates.responsible_role = body.responsible_role ?? null;
    if (body.responsible_user_id !== undefined) updates.responsible_user_id = body.responsible_user_id ?? null;
    if (body.rera_escalation_eligible !== undefined) updates.rera_escalation_eligible = body.rera_escalation_eligible;
    if (body.governance_notes !== undefined) updates.governance_notes = body.governance_notes?.trim() ?? null;

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No fields to update' }, { status: 400 });
    }

    const { data: updated, error: updateErr } = await sb
      .from('hoto_items')
      .update(updates)
      .eq('id', itemId)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'hoto_items', resourceId: itemId,
      ip: extractClientIP(request),
      newValues: updates as Record<string, unknown>,
    });

    return Response.json({ success: true, item: updated });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
