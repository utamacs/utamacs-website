import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PUT — submit a draft document for approval
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only executives and admins can submit AGM documents' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: doc } = await sb
      .from('agm_documents')
      .select('id, status, created_by, document_type, title')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!doc) {
      return new Response(JSON.stringify({ error: 'Document not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((doc as any).status !== 'draft') {
      return new Response(JSON.stringify({ error: `Document is already '${(doc as any).status}'. Only drafts can be submitted.` }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('agm_documents')
      .update({
        status: 'submitted',
        submitted_by: user.id,
        submitted_at: new Date().toISOString(),
      })
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await sb.from('agm_workflow_history').insert({
      agm_document_id: params.id!,
      society_id: SOCIETY_ID,
      old_status: 'draft',
      new_status: 'submitted',
      action: 'SUBMITTED',
      actor_id: user.id,
    });

    // Notify admins that a document needs review
    const { data: admins } = await sb
      .from('user_roles')
      .select('user_id')
      .eq('society_id', SOCIETY_ID)
      .eq('role', 'admin');

    if (admins?.length) {
      const notifications = (admins as any[]).map((a: any) => ({
        society_id: SOCIETY_ID,
        user_id: a.user_id,
        title: 'AGM Document Submitted for Review',
        body: `"${(doc as any).title}" has been submitted and requires your approval.`,
        type: 'system',
        reference_table: 'agm_documents',
        reference_id: params.id!,
        channel: 'in_app',
        status: 'pending',
      }));
      await sb.from('notifications').insert(notifications);
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'agm_documents', resourceId: params.id!,
      ip: extractClientIP(request),
      oldValues: { status: 'draft' }, newValues: { status: 'submitted' },
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
