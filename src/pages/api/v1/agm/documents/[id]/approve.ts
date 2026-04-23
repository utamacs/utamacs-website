export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PUT — approve a submitted document (admin only)
// Financial statements require dual approval: first exec/admin sets secondary_approved_at,
// then admin sets status='approved'. For non-financial docs, single admin approval suffices.
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (user.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Only admins can approve AGM documents' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json().catch(() => ({})) as { comment?: string; is_public?: boolean };
    const sb = getSupabaseServiceClient();

    const { data: doc } = await sb
      .from('agm_documents')
      .select('id, status, document_type, title, submitted_by, secondary_approver_id, secondary_approved_at')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!doc) {
      return new Response(JSON.stringify({ error: 'Document not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((doc as any).status !== 'submitted') {
      return new Response(JSON.stringify({ error: `Document is '${(doc as any).status}'. Only submitted documents can be approved.` }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Financial documents require dual approval
    const requiresDual = ['financial_statement', 'audit_report'].includes((doc as any).document_type);
    if (requiresDual && !(doc as any).secondary_approved_at) {
      return new Response(JSON.stringify({
        error: 'Financial documents require secondary approval before final approval. Please ensure an executive has provided secondary sign-off first.',
        requires_secondary_approval: true,
      }), { status: 422, headers: { 'Content-Type': 'application/json' } });
    }

    const isPublic = body.is_public !== undefined ? body.is_public : false;

    const { data, error } = await sb
      .from('agm_documents')
      .update({
        status: 'approved',
        reviewed_by: user.id,
        reviewed_at: new Date().toISOString(),
        review_comment: body.comment ?? null,
        is_public: isPublic,
      })
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await sb.from('agm_workflow_history').insert({
      agm_document_id: params.id!,
      society_id: SOCIETY_ID,
      old_status: 'submitted',
      new_status: 'approved',
      action: 'APPROVED',
      actor_id: user.id,
      comment: body.comment ?? null,
    });

    if (isPublic) {
      await sb.from('agm_workflow_history').insert({
        agm_document_id: params.id!,
        society_id: SOCIETY_ID,
        old_status: 'approved',
        new_status: 'approved',
        action: 'PUBLISHED',
        actor_id: user.id,
        comment: 'Document made public for all members',
      });
    }

    // Notify submitter
    if ((doc as any).submitted_by) {
      await sb.from('notifications').insert({
        society_id: SOCIETY_ID,
        user_id: (doc as any).submitted_by,
        title: 'AGM Document Approved',
        body: `"${(doc as any).title}" has been approved${isPublic ? ' and published to members' : ''}.`,
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
      oldValues: { status: 'submitted' }, newValues: { status: 'approved', is_public: isPublic },
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
