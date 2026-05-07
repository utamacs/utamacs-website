export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const BUCKET = 'notices';
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

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
    if (bytes.byteLength > MAX_BYTES)
      return Response.json({ error: 'VALIDATION_ERROR', message: 'File must be under 10 MB' }, { status: 400 });

    const storageKey = `${SOCIETY_ID}/${noticeId}.${meta.ext}`;
    const storage = new SupabaseStorageService();
    await sb.storage.from(BUCKET).upload(storageKey, Buffer.from(bytes), { contentType: file.type, upsert: true });

    const { signedUrl } = (await sb.storage.from(BUCKET).createSignedUrl(storageKey, 3600)).data ?? {};

    const { error: updErr } = await sb
      .from('notices')
      .update({
        attachment_storage_key: storageKey,
        attachment_type: meta.type,
        updated_at: new Date().toISOString(),
      })
      .eq('id', noticeId)
      .eq('society_id', SOCIETY_ID);

    if (updErr) throw Object.assign(new Error(updErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'notices', resourceId: noticeId,
      ip: extractClientIP(request),
      newValues: { attachment_type: meta.type },
    });

    return Response.json({ storage_key: storageKey, attachment_type: meta.type, url: signedUrl }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
