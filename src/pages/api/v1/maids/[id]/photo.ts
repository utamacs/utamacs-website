export const prerender = false;
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const ALLOWED_MIME: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
const MAX_SIZE = 5 * 1024 * 1024;

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const maidId = params.id!;
    if (!UUID_RE.test(maidId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data: maid } = await sb.from('maids').select('id').eq('id', maidId).eq('society_id', SOCIETY_ID).single();
    if (!maid) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    if (!file) return Response.json({ error: 'NO_FILE' }, { status: 400 });

    const ext = ALLOWED_MIME[file.type];
    if (!ext) return Response.json({ error: 'INVALID_TYPE', message: 'Only JPEG, PNG, or WebP images allowed.' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    if (buffer.length > MAX_SIZE) return Response.json({ error: 'TOO_LARGE', message: 'Photo must be under 5 MB.' }, { status: 400 });

    const key = `maids/${SOCIETY_ID}/${maidId}/photo-${crypto.randomUUID()}.${ext}`;
    const storage = new SupabaseStorageService();
    const { storageKey } = await storage.upload('maid-documents', key, buffer, file.type);

    await sb.from('maids').update({ photo_key: storageKey }).eq('id', maidId);

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'maid', resourceId: maidId,
      ip: extractClientIP(request),
      newValues: { photo_key: storageKey },
    });

    const signedUrl = await storage.getSignedUrl('maid-documents', storageKey, 3600);
    return Response.json({ storage_key: storageKey, signed_url: signedUrl }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
