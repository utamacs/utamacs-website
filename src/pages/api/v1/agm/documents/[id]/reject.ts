import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PUT — reject a submitted document (admin only) with required comment
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (user.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Only admins can reject AGM documents' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json().catch(() => ({})) as { comment?: string };

    if (!body.comment?.trim()) {
      return new Response(JSON.stringify({ error: 'A rejection comment is required to explain why the document was rejected.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: doc } = await sb
      .from('agm_documents')
      .select('id, status, title, submitted_by')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!doc) {
      return new Response(JSON.stringify({ error: 'Document not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((doc as any).status !== 'submitted') {
      return new Response(JSON.stringify({ error: `Document is '${(doc as any).status}'. Only submitted documents can be rejected.` }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('agm_documents')
      .update({
        status: 'rejected',
        reviewed_by: user.id,
        reviewed_at: new Date().toISOString(),
        review_comment: body.comment.trim(),
      })
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await sb.from('agm_workflow_history').insert({
      agm_document_id: params.id!,
      society_id: SOCIETY_ID,
      old_status: 'submitted',
      new_status: 'rejected',
      action: 'REJECTED',
      actor_id: user.id,
      comment: body.comment.trim(),
    });

    // Notify submitter
    if ((doc as any).submitted_by) {
      await sb.from('notifications').insert({
        society_id: SOCIETY_ID,
        user_id: (doc as any).submitted_by,
        title: 'AGM Document Rejected',
        body: `"${(doc as any).title}" was rejected. Reason: ${body.comment.trim()}`,
        type: 'system',
        reference_table: 'agm_documents',
        reference_id: params.id!,
        channel: 'in_app',
        status: 'pending',
      });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'agm_documents', resourceId: params.id!,
      ip: extractClientIP(request),
      oldValues: { status: 'submitted' }, newValues: { status: 'rejected', review_comment: body.comment },
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
