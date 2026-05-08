export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png':  'png',
  'image/webp': 'webp',
};
const MAX_BYTES = 2 * 1024 * 1024; // 2 MB

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);

    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    if (!file) return Response.json({ error: 'VALIDATION', message: 'No file provided' }, { status: 400 });

    const ext = ALLOWED_MIME[file.type];
    if (!ext) return Response.json({ error: 'VALIDATION', message: 'Only JPEG, PNG, or WebP avatars allowed' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    if (buffer.length > MAX_BYTES) return Response.json({ error: 'VALIDATION', message: 'Avatar must be ≤2 MB' }, { status: 400 });

    const githubPath = docPath.avatar(user.id, ext);
    const result = await commitDocument(githubPath, buffer, `docs: avatar for member ${user.id}`);

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('profiles')
      .update({ avatar_key: result.githubPath, updated_at: new Date().toISOString() })
      .eq('id', user.id);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const signed_url = await getDocumentDownloadUrl(result.githubPath);

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'profile_avatar', resourceId: user.id,
      ip: extractClientIP(request),
      newValues: { avatar_key: result.githubPath },
    });

    return Response.json({ storage_key: result.githubPath, signed_url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
