export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const BUCKET     = 'community';
const MAX_BYTES  = 5 * 1024 * 1024; // 5 MB per image
const MAX_IMAGES = 5;

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png':  'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
};

// POST — upload up to 5 images for a community post
// Body: multipart/form-data, field name "images" (repeatable)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const postId = params.id!;

    const sb = getSupabaseServiceClient();
    const { data: post, error: pErr } = await sb
      .from('community_posts')
      .select('id, society_id, author_id, images')
      .eq('id', postId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (pErr || !post) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (post.author_id !== user.id) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const existingCount = (post.images ?? []).length;
    if (existingCount >= MAX_IMAGES)
      return Response.json({ error: 'VALIDATION_ERROR', message: `Maximum ${MAX_IMAGES} images per post` }, { status: 400 });

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const files = formData.getAll('images') as File[];
    if (!files.length) return Response.json({ error: 'VALIDATION_ERROR', message: 'No images provided' }, { status: 400 });

    const remaining = MAX_IMAGES - existingCount;
    if (files.length > remaining)
      return Response.json({ error: 'VALIDATION_ERROR', message: `Can only add ${remaining} more image(s)` }, { status: 400 });

    const storage = new SupabaseStorageService();
    const newKeys: string[] = [];

    for (const file of files) {
      if (!(file instanceof File)) continue;
      const ext = ALLOWED_MIME[file.type];
      if (!ext) return Response.json({ error: 'VALIDATION_ERROR', message: `File type ${file.type} not allowed. Only images.` }, { status: 400 });
      const bytes = await file.arrayBuffer();
      if (bytes.byteLength > MAX_BYTES) return Response.json({ error: 'VALIDATION_ERROR', message: `${file.name} exceeds 5 MB limit` }, { status: 400 });

      const key = `${SOCIETY_ID}/${postId}/${crypto.randomUUID()}.${ext}`;
      await storage.upload(BUCKET, key, Buffer.from(bytes), file.type);
      newKeys.push(key);
    }

    const updatedImages = [...(post.images ?? []), ...newKeys];
    const { error: updErr } = await sb
      .from('community_posts')
      .update({ images: updatedImages, updated_at: new Date().toISOString() })
      .eq('id', postId)
      .eq('society_id', SOCIETY_ID);

    if (updErr) throw Object.assign(new Error(updErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'community_posts', resourceId: postId,
      ip: extractClientIP(request),
      newValues: { images_added: newKeys.length },
    });

    // Return signed URLs for the newly uploaded images
    const urls = await Promise.all(
      newKeys.map(k => storage.getSignedUrl(BUCKET, k, 3600))
    );

    return Response.json({ keys: newKeys, urls }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
