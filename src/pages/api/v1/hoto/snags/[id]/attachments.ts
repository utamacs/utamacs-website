export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { commitDocument, getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg':  'jpg',
  'image/png':   'png',
  'image/webp':  'webp',
  'image/heic':  'heic',
  'video/mp4':   'mp4',
};

// GET /api/v1/hoto/snags/:id/attachments
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'snag.view');

    const snagItemId = params.id ?? '';
    if (!snagItemId) return Response.json({ error: 'VALIDATION', message: 'Snag id required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('snag_attachments')
      .select('id, snag_item_id, storage_key, mime_type, caption, uploaded_by, created_at')
      .eq('snag_item_id', snagItemId)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const withUrls = await Promise.all(
      (data ?? []).map(async (a: any) => {
        let signed_url: string | null = null;
        try { signed_url = await getDocumentDownloadUrl(a.storage_key); } catch { /* skip */ }
        return { ...a, signed_url };
      })
    );

    return Response.json(withUrls);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/hoto/snags/:id/attachments  (multipart — file + caption?)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'snag.create');

    const snagItemId = params.id ?? '';
    if (!snagItemId) return Response.json({ error: 'VALIDATION', message: 'Snag id required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_SNAGS_MB']);
    const maxBytes = ruleInt(rules, 'UPLOAD_LIMIT_SNAGS_MB', 50) * 1024 * 1024;

    // Verify snag belongs to society
    const { data: snag } = await sb
      .from('snag_items')
      .select('id')
      .eq('id', snagItemId)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    if (!snag) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const formData = await request.formData();
    const file     = formData.get('file') as File | null;
    const caption  = (formData.get('caption') as string | null)?.trim().slice(0, 200) ?? null;

    if (!file) return Response.json({ error: 'VALIDATION', message: 'No file provided' }, { status: 400 });

    const ext = ALLOWED_MIME[file.type];
    if (!ext) return Response.json({ error: 'VALIDATION', message: 'Unsupported file type' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    if (buffer.length > maxBytes) return Response.json({ error: 'VALIDATION', message: `File exceeds ${ruleInt(rules, 'UPLOAD_LIMIT_SNAGS_MB', 50)} MB limit` }, { status: 400 });

    const key = `snags/${snagItemId}/${Date.now()}-attachment.${ext}`;
    const result = await commitDocument(key, buffer, `docs: snag ${snagItemId} attachment`);

    const { data, error } = await sb
      .from('snag_attachments')
      .insert({
        society_id:   SOCIETY_ID,
        snag_item_id: snagItemId,
        storage_key:  result.githubPath,
        mime_type:    file.type,
        uploaded_by:  user.id,
        caption,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    let signed_url: string | null = null;
    try { signed_url = await getDocumentDownloadUrl(result.githubPath); } catch { /* non-fatal */ }

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'CREATE', resourceType: 'snag_attachment', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { snag_item_id: snagItemId, mime_type: file.type },
    });

    return Response.json({ ...data, signed_url }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/hoto/snags/:id/attachments?attachment_id=<uuid>
export const DELETE: APIRoute = async ({ request, params, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'snag.delete');

    const attachmentId = url.searchParams.get('attachment_id') ?? '';
    if (!UUID_RE.test(attachmentId)) return Response.json({ error: 'VALIDATION', message: 'Invalid attachment_id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('snag_attachments')
      .delete()
      .eq('id', attachmentId)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'DELETE', resourceType: 'snag_attachment', resourceId: attachmentId,
      ip: extractClientIP(request),
    });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
