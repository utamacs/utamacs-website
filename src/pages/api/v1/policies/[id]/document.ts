export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST — upload PDF document for a policy (policies.manage required)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'policies.manage');

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_POLICIES_MB']);
    const maxBytes = ruleInt(rules, 'UPLOAD_LIMIT_POLICIES_MB', 20) * 1024 * 1024;

    const { data: policy, error: pErr } = await sb
      .from('policies')
      .select('id, policy_type')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (pErr || !policy) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const file = formData.get('file') as File | null;
    if (!file || !(file instanceof File)) return Response.json({ error: 'VALIDATION_ERROR', message: 'file is required' }, { status: 400 });
    if (file.type !== 'application/pdf') return Response.json({ error: 'VALIDATION_ERROR', message: 'Only PDF files allowed' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    if (bytes.byteLength > maxBytes) return Response.json({ error: 'VALIDATION_ERROR', message: `PDF must be under ${ruleInt(rules, 'UPLOAD_LIMIT_POLICIES_MB', 20)} MB` }, { status: 400 });

    // Use slug derived from policy id for the filename component
    const githubPath = docPath.policy(params.id!, 1, params.id!, 'pdf');
    const result = await commitDocument(githubPath, Buffer.from(bytes), `docs: policy ${params.id!} document upload`);

    const { error: updErr } = await sb
      .from('policies')
      .update({ document_key: result.githubPath, policy_type: 'pdf', updated_at: new Date().toISOString() })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID);

    if (updErr) throw Object.assign(new Error(updErr.message), { status: 500 });

    const signed_url = await getDocumentDownloadUrl(result.githubPath);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'policies', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { document_uploaded: true },
    });

    return Response.json({ document_key: result.githubPath, signed_url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
