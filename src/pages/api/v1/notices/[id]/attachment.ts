export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/** GET /api/v1/notices/:id/attachment — returns 1-hour signed URL for the notice attachment. */
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: notice } = await sb
      .from('notices')
      .select('id, attachment_storage_key, attachment_type')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .single();

    if (!notice || !(notice as any).attachment_storage_key) {
      return Response.json({ error: 'No attachment found' }, { status: 404 });
    }

    const url = await getDocumentDownloadUrl((notice as any).attachment_storage_key);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'EXPORT', resourceType: 'notices', resourceId: params.id!,
      ip: extractClientIP(request),
    });

    return Response.json({
      url,
      attachment_type: (notice as any).attachment_type,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

const ALLOWED_MIME: Record<string, { ext: string; type: 'image' | 'pdf' }> = {
  'image/jpeg': { ext: 'jpg',  type: 'image' },
  'image/png':  { ext: 'png',  type: 'image' },
  'image/webp': { ext: 'webp', type: 'image' },
  'application/pdf': { ext: 'pdf', type: 'pdf' },
};

// POST — upload attachment for a notice (image or PDF)
// Body: multipart/form-data with field "file"
// Returns: { storage_key, attachment_type, url }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const noticeId = params.id!;
    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_NOTICES_MB']);
    const maxBytes = ruleInt(rules, 'UPLOAD_LIMIT_NOTICES_MB', 10) * 1024 * 1024;

    const { data: notice, error: nErr } = await sb
      .from('notices')
      .select('id, society_id, created_by')
      .eq('id', noticeId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (nErr || !notice) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const file = formData.get('file') as File | null;
    if (!file || !(file instanceof File))
      return Response.json({ error: 'VALIDATION_ERROR', message: 'file is required' }, { status: 400 });

    const meta = ALLOWED_MIME[file.type];
    if (!meta) return Response.json({ error: 'VALIDATION_ERROR', message: 'Only JPEG, PNG, WebP, or PDF allowed' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    if (bytes.byteLength > maxBytes)
      return Response.json({ error: 'VALIDATION_ERROR', message: `File must be under ${ruleInt(rules, 'UPLOAD_LIMIT_NOTICES_MB', 10)} MB` }, { status: 400 });

    const githubPath = docPath.notice(noticeId, 'attachment', meta.ext);
    const result = await commitDocument(githubPath, Buffer.from(bytes), `docs: notice ${noticeId} attachment`);

    const { error: updErr } = await sb
      .from('notices')
      .update({
        attachment_storage_key: result.githubPath,
        attachment_type: meta.type,
        updated_at: new Date().toISOString(),
      })
      .eq('id', noticeId)
      .eq('society_id', SOCIETY_ID);

    if (updErr) throw Object.assign(new Error(updErr.message), { status: 500 });

    const url = await getDocumentDownloadUrl(result.githubPath);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'notices', resourceId: noticeId,
      ip: extractClientIP(request),
      newValues: { attachment_type: meta.type },
    });

    return Response.json({ storage_key: result.githubPath, attachment_type: meta.type, url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
