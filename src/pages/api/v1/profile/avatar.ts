export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const MAX_BYTES  = 2 * 1024 * 1024; // 2 MB

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png':  'png',
  'image/webp': 'webp',
};

// POST — upload or replace the member's profile photo
// Body: multipart/form-data with field "file"
// Returns: { avatar_url: string }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const file = formData.get('file') as File | null;
    if (!file || !(file instanceof File))
      return Response.json({ error: 'VALIDATION_ERROR', message: 'file is required' }, { status: 400 });

    const ext = ALLOWED_MIME[file.type];
    if (!ext)
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Only JPEG, PNG, or WebP allowed' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    if (bytes.byteLength > MAX_BYTES)
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Photo must be under 2 MB' }, { status: 400 });

    const githubPath = docPath.avatar(user.id, ext);
    const result = await commitDocument(githubPath, Buffer.from(bytes), `docs: avatar for profile ${user.id}`);

    const sb = getSupabaseServiceClient();
    const avatar_url = await getDocumentDownloadUrl(result.githubPath);

    // Persist url to profile
    const { error: updateErr } = await sb
      .from('profiles')
      .update({ avatar_url: result.githubPath, updated_at: new Date().toISOString() })
      .eq('id', user.id)
      .eq('society_id', SOCIETY_ID);

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'profiles', resourceId: user.id,
      ip: extractClientIP(request),
      newValues: { avatar_updated: true },
    });

    return Response.json({ avatar_url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
