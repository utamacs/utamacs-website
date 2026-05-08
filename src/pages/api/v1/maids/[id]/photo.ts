export const prerender = false;
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
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

    const githubPath = docPath.maidKycPhoto(maidId, ext);
    const result = await commitDocument(githubPath, buffer, `docs: maid ${maidId} photo`);

    await sb.from('maids').update({ photo_key: result.githubPath }).eq('id', maidId);

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'maid', resourceId: maidId,
      ip: extractClientIP(request),
      newValues: { photo_key: result.githubPath },
    });

    const signed_url = await getDocumentDownloadUrl(result.githubPath);
    return Response.json({ storage_key: result.githubPath, signed_url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
