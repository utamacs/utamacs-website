export const prerender = false;
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic',
};
const MAX_SIZE = 10 * 1024 * 1024;
const MAX_PHOTOS_PER_UPLOAD = 10;

// GET — list photos in an album with signed URLs
export const GET: APIRoute = async ({ request, params }) => {
  try {
    await validateJWT(request);
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

    const storage = new SupabaseStorageService();
    const photos = await Promise.all(
      ((data ?? []) as any[]).map(async (p) => {
        let url: string | null = null;
        try { url = await storage.getSignedUrl('gallery-photos', p.storage_key, 3600); } catch { /* non-fatal */ }
        return { ...p, url };
      })
    );

    return Response.json(photos);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — upload photos to an album (exec only, multipart, up to 10 files)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

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

    const storage = new SupabaseStorageService();
    const results: { id: string; storage_key: string; url: string | null }[] = [];

    for (const file of files) {
      const ext = ALLOWED_MIME[file.type];
      if (!ext) continue; // skip invalid types silently

      const bytes = await file.arrayBuffer();
      const buffer = Buffer.from(bytes);
      if (buffer.length > MAX_SIZE) continue; // skip oversized

      const key = `gallery/${SOCIETY_ID}/${albumId}/${crypto.randomUUID()}.${ext}`;
      const { storageKey } = await storage.upload('gallery-photos', key, buffer, file.type);

      const caption = formData.get('caption') as string | null;
      const { data: photo } = await sb
        .from('gallery_photos')
        .insert({
          society_id: SOCIETY_ID,
          album_id: albumId,
          storage_key: storageKey,
          caption: caption ? sanitizePlainText(caption).slice(0, 300) : null,
          uploaded_by: user.id,
        })
        .select('id, storage_key')
        .single();

      let url: string | null = null;
      try { url = await storage.getSignedUrl('gallery-photos', storageKey, 3600); } catch { /* non-fatal */ }

      results.push({ id: (photo as any).id, storage_key: storageKey, url });

      // Set first upload as cover if album has no cover
      if (!(album as any).cover_key && results.length === 1) {
        await sb.from('gallery_albums').update({ cover_key: storageKey }).eq('id', albumId);
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
