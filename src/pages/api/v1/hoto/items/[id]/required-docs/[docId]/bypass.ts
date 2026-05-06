export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST — bypass a required document (mark as waived without uploading)
// Auth: hoto.bypass_required_docs feature required (secretary or president only)
// Body: { bypass_reason }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.bypass_required_docs');

    const itemId = params.id!;
    const docId  = params.docId!;

    const body = await request.json() as { bypass_reason?: string };

    if (!body.bypass_reason?.trim()) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: 'bypass_reason is required',
      }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify the required doc belongs to this item in this society
    const { data: doc, error: fetchErr } = await sb
      .from('hoto_required_docs')
      .select('id, hoto_item_id, doc_name, uploaded, bypass_by')
      .eq('id', docId)
      .eq('hoto_item_id', itemId)
      .single();

    if (fetchErr || !doc) {
      return Response.json({ error: 'NOT_FOUND', message: 'Required document not found' }, { status: 404 });
    }

    if ((doc as any).uploaded) {
      return Response.json({ error: 'CONFLICT', message: 'Document is already uploaded' }, { status: 409 });
    }

    if ((doc as any).bypass_by) {
      return Response.json({ error: 'CONFLICT', message: 'Document has already been bypassed' }, { status: 409 });
    }

    const { data: updated, error: updateErr } = await sb
      .from('hoto_required_docs')
      .update({
        bypass_by: user.id,
        bypass_reason: body.bypass_reason.trim(),
      })
      .eq('id', docId)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // Log to hoto_audit_log
    const { error: auditHotoErr } = await sb.from('hoto_audit_log').insert({
      society_id: SOCIETY_ID,
      actor_id: user.id,
      action: 'BYPASS_REQUIRED_DOC',
      resource_type: 'hoto_required_docs',
      resource_id: docId,
      old_values: { uploaded: false },
      new_values: {
        bypass_reason: body.bypass_reason.trim(),
        hoto_item_id: itemId,
        doc_name: (doc as any).doc_name,
      },
    });
    if (auditHotoErr) console.error('[bypass] hoto_audit_log insert failed:', auditHotoErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'hoto_required_docs', resourceId: docId,
      ip: extractClientIP(request),
      newValues: { bypass_reason: body.bypass_reason.trim() },
    });

    return Response.json({ success: true, doc: updated });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
