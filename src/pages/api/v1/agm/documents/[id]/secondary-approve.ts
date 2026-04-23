import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PUT — secondary approval for financial documents (exec/admin, different from final approver)
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only executives and admins can provide secondary approval' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json().catch(() => ({})) as { comment?: string };
    const sb = getSupabaseServiceClient();

    const { data: doc } = await sb
      .from('agm_documents')
      .select('id, status, document_type, title, submitted_by, secondary_approver_id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!doc) {
      return new Response(JSON.stringify({ error: 'Document not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((doc as any).status !== 'submitted') {
      return new Response(JSON.stringify({ error: `Document must be in submitted status. Currently '${(doc as any).status}'.` }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((doc as any).secondary_approver_id) {
      return new Response(JSON.stringify({ error: 'Secondary approval already provided.' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!['financial_statement', 'audit_report'].includes((doc as any).document_type)) {
      return new Response(JSON.stringify({ error: 'Secondary approval is only required for financial statements and audit reports.' }), {
        status: 422, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('agm_documents')
      .update({
        secondary_approver_id: user.id,
        secondary_approved_at: new Date().toISOString(),
        secondary_comment: body.comment ?? null,
      })
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await sb.from('agm_workflow_history').insert({
      agm_document_id: params.id!,
      society_id: SOCIETY_ID,
      old_status: 'submitted',
      new_status: 'submitted',
      action: 'SECONDARY_APPROVED',
      actor_id: user.id,
      comment: body.comment ?? 'Secondary approval provided',
    });

    // Notify admins that secondary approval is done and final approval is ready
    const { data: admins } = await sb
      .from('user_roles')
      .select('user_id')
      .eq('society_id', SOCIETY_ID)
      .eq('role', 'admin');

    if (admins?.length) {
      await sb.from('notifications').insert(
        (admins as any[]).map((a: any) => ({
          society_id: SOCIETY_ID,
          user_id: a.user_id,
          title: 'AGM Document Ready for Final Approval',
          body: `"${(doc as any).title}" has received secondary approval and is ready for your final approval.`,
          type: 'system',
          reference_table: 'agm_documents',
          reference_id: params.id!,
          channel: 'in_app',
          status: 'pending',
        }))
      );
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'agm_documents', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { secondary_approver_id: user.id, secondary_approved_at: new Date().toISOString() },
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
