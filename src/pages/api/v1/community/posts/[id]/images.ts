export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
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
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_COMMUNITY_MB', 'COMMUNITY_POST_MAX_IMAGES']);
    const maxBytes = ruleInt(rules, 'UPLOAD_LIMIT_COMMUNITY_MB', 5) * 1024 * 1024;
    const maxImages = ruleInt(rules, 'COMMUNITY_POST_MAX_IMAGES', 5);

    const { data: post, error: pErr } = await sb
      .from('community_posts')
      .select('id, society_id, author_id, images')
      .eq('id', postId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (pErr || !post) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (post.author_id !== user.id) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const existingCount = (post.images ?? []).length;
    if (existingCount >= maxImages)
      return Response.json({ error: 'VALIDATION_ERROR', message: `Maximum ${maxImages} images per post` }, { status: 400 });

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const files = formData.getAll('images') as File[];
    if (!files.length) return Response.json({ error: 'VALIDATION_ERROR', message: 'No images provided' }, { status: 400 });

    const remaining = maxImages - existingCount;
    if (files.length > remaining)
      return Response.json({ error: 'VALIDATION_ERROR', message: `Can only add ${remaining} more image(s)` }, { status: 400 });

    const newKeys: string[] = [];

    for (const file of files) {
      if (!(file instanceof File)) continue;
      const ext = ALLOWED_MIME[file.type];
      if (!ext) return Response.json({ error: 'VALIDATION_ERROR', message: `File type ${file.type} not allowed. Only images.` }, { status: 400 });
      const bytes = await file.arrayBuffer();
      if (bytes.byteLength > maxBytes) return Response.json({ error: 'VALIDATION_ERROR', message: `${file.name} exceeds ${ruleInt(rules, 'UPLOAD_LIMIT_COMMUNITY_MB', 5)} MB limit` }, { status: 400 });

      const githubPath = docPath.communityImage(postId, ext);
      const result = await commitDocument(githubPath, Buffer.from(bytes), `docs: community post ${postId} image`);
      newKeys.push(result.githubPath);
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

    // Return download URLs for the newly uploaded images
    const urls = await Promise.all(
      newKeys.map(k => getDocumentDownloadUrl(k))
    );

    return Response.json({ keys: newKeys, urls }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
