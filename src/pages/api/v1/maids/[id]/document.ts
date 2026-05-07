export const prerender = false;
// Police verification document upload for domestic helpers.
// Accepts: image/jpeg, image/png, image/webp, application/pdf (max 5 MB)
// Stores in maid-documents Supabase bucket.
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const BUCKET = 'maid-documents';
const MAX_BYTES = 5 * 1024 * 1024; // 5 MB

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
};

/** GET — returns 1-hour signed URL for the verification document */
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const sb = getSupabaseServiceClient();
    const { data: maid } = await sb
      .from('maids')
      .select('id, id_doc_key')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!maid) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (!(maid as any).id_doc_key) return Response.json({ error: 'No document uploaded' }, { status: 404 });

    const { data: signed } = await sb.storage
      .from(BUCKET)
      .createSignedUrl((maid as any).id_doc_key, 3600);

    if (!signed?.signedUrl) return Response.json({ error: 'Could not generate URL' }, { status: 500 });

    // Audit log: exec accessed personal identity document
    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'EXPORT', resourceType: 'maids', resourceId: params.id!,
      ip: extractClientIP(request),
    });

    return Response.json({ url: signed.signedUrl });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

/** POST — upload police verification / ID document for a maid */
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const sb = getSupabaseServiceClient();
    const { data: maid } = await sb
      .from('maids')
      .select('id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!maid) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const file = formData.get('file') as File | null;
    if (!file || !(file instanceof File)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'file is required' }, { status: 400 });
    }

    const ext = ALLOWED_MIME[file.type];
    if (!ext) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Only JPEG, PNG, WebP, or PDF allowed' }, { status: 400 });
    }

    const bytes = await file.arrayBuffer();
    if (bytes.byteLength > MAX_BYTES) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'File must be under 5 MB' }, { status: 400 });
    }

    const storageKey = `${SOCIETY_ID}/${params.id!}/verification.${ext}`;
    await sb.storage.from(BUCKET).upload(storageKey, Buffer.from(bytes), {
      contentType: file.type,
      upsert: true,
    });

    const { error: updErr } = await sb
      .from('maids')
      .update({ id_doc_key: storageKey })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID);

    if (updErr) throw Object.assign(new Error(updErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'maids', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { id_doc_key: storageKey },
    });

    const { data: signed } = await sb.storage.from(BUCKET).createSignedUrl(storageKey, 3600);
    return Response.json({ storage_key: storageKey, url: signed?.signedUrl }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
