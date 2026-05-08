export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic',
};
const MAX_SIZE = 10 * 1024 * 1024;
const MAX_PHOTOS_PER_UPLOAD = 10;

// GET — list photos in an album with download URLs
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'gallery.view');
    const albumId = params.id!;
    if (!UUID_RE.test(albumId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('gallery_photos')
      .select('id, storage_key, caption, taken_at, created_at')
      .eq('album_id', albumId)
      .eq('society_id', SOCIETY_ID)
      .order('taken_at', { ascending: true, nullsFirst: false })
      .order('created_at', { ascending: true });

    if (error) throw error;

    const photos = await Promise.all(
      ((data ?? []) as any[]).map(async (p) => {
        let url: string | null = null;
        try { url = await getDocumentDownloadUrl(p.storage_key); } catch { /* non-fatal */ }
        return { ...p, url };
      })
    );

    return Response.json(photos);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — upload photos to an album (gallery.manage feature required)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'gallery.manage');

    const albumId = params.id!;
    if (!UUID_RE.test(albumId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data: album } = await sb
      .from('gallery_albums')
      .select('id, cover_key')
      .eq('id', albumId)
      .eq('society_id', SOCIETY_ID)
      .single();
    if (!album) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const formData = await request.formData();
    const files = formData.getAll('files') as File[];
    if (!files.length) return Response.json({ error: 'NO_FILES' }, { status: 400 });
    if (files.length > MAX_PHOTOS_PER_UPLOAD) {
      return Response.json({ error: 'TOO_MANY', message: `Max ${MAX_PHOTOS_PER_UPLOAD} files per upload.` }, { status: 400 });
    }

    const results: { id: string; storage_key: string; url: string | null }[] = [];

    for (const file of files) {
      const ext = ALLOWED_MIME[file.type];
      if (!ext) continue; // skip invalid types silently

      const bytes = await file.arrayBuffer();
      const buffer = Buffer.from(bytes);
      if (buffer.length > MAX_SIZE) continue; // skip oversized

      const photoId = crypto.randomUUID();
      const githubPath = docPath.galleryPhoto(albumId, photoId, ext);
      const result = await commitDocument(githubPath, buffer, `docs: gallery album ${albumId} photo`);

      const caption = formData.get('caption') as string | null;
      const { data: photo } = await sb
        .from('gallery_photos')
        .insert({
          society_id: SOCIETY_ID,
          album_id: albumId,
          storage_key: result.githubPath,
          caption: caption ? sanitizePlainText(caption).slice(0, 300) : null,
          uploaded_by: user.id,
        })
        .select('id, storage_key')
        .single();

      let url: string | null = null;
      try { url = await getDocumentDownloadUrl(result.githubPath); } catch { /* non-fatal */ }

      results.push({ id: (photo as any).id, storage_key: result.githubPath, url });

      // Set first upload as cover if album has no cover
      if (!(album as any).cover_key && results.length === 1) {
        await sb.from('gallery_albums').update({ cover_key: result.githubPath }).eq('id', albumId);
      }
    }

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'CREATE', resourceType: 'gallery_photo',
      resourceId: albumId,
      ip: extractClientIP(request),
      newValues: { count: results.length, album_id: albumId },
    });

    return Response.json({ uploaded: results.length, photos: results }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
