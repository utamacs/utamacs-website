export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const MAX_FILES  = 5;

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg':       'jpg',
  'image/png':        'png',
  'image/webp':       'webp',
  'image/heic':       'heic',
  'application/pdf':  'pdf',
};

// POST — upload one or more attachments for a complaint
// Body: multipart/form-data, field name "files" (repeatable)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const complaintId = params.id!;

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_COMPLAINTS_MB']);
    const maxBytes = ruleInt(rules, 'UPLOAD_LIMIT_COMPLAINTS_MB', 50) * 1024 * 1024;

    const { data: complaint, error: cErr } = await sb
      .from('complaints')
      .select('id, society_id, raised_by, status')
      .eq('id', complaintId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (cErr || !complaint) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (complaint.raised_by !== user.id) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    if (['Resolved', 'Closed'].includes(complaint.status))
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Cannot add attachments to a resolved/closed complaint' }, { status: 400 });

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const files = formData.getAll('files') as File[];
    if (!files.length) return Response.json({ error: 'VALIDATION_ERROR', message: 'No files provided' }, { status: 400 });
    if (files.length > MAX_FILES) return Response.json({ error: 'VALIDATION_ERROR', message: `Max ${MAX_FILES} files per upload` }, { status: 400 });

    const saved: { storage_key: string; file_name: string; mime_type: string; file_size_bytes: number }[] = [];

    for (const file of files) {
      if (!(file instanceof File)) continue;
      const ext = ALLOWED_MIME[file.type];
      if (!ext) return Response.json({ error: 'VALIDATION_ERROR', message: `File type ${file.type} not allowed. Only images and PDF.` }, { status: 400 });
      const bytes = await file.arrayBuffer();
      if (bytes.byteLength > maxBytes) return Response.json({ error: 'VALIDATION_ERROR', message: `File ${file.name} exceeds ${ruleInt(rules, 'UPLOAD_LIMIT_COMPLAINTS_MB', 50)} MB limit` }, { status: 400 });

      const githubPath = docPath.complaintAttachment(complaintId, ext);
      const result = await commitDocument(githubPath, Buffer.from(bytes), `docs: complaint ${complaintId} attachment`);
      saved.push({ storage_key: result.githubPath, file_name: file.name, mime_type: file.type, file_size_bytes: bytes.byteLength });
    }

    const { data: rows, error: insErr } = await sb
      .from('complaint_attachments')
      .insert(saved.map(s => ({
        complaint_id:    complaintId,
        society_id:      SOCIETY_ID,
        storage_key:     s.storage_key,
        file_name:       s.file_name,
        mime_type:       s.mime_type,
        file_size_bytes: s.file_size_bytes,
        uploaded_by:     user.id,
      })))
      .select('id, file_name, mime_type, file_size_bytes, created_at');

    if (insErr) throw Object.assign(new Error(insErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'complaint_attachments', resourceId: complaintId,
      ip: extractClientIP(request),
      newValues: { count: saved.length },
    });

    return Response.json(rows, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// GET — list attachments for a complaint (returns download URLs, valid ~1 hour)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const complaintId = params.id!;

    const sb = getSupabaseServiceClient();
    const { data: complaint, error: cErr } = await sb
      .from('complaints')
      .select('id, raised_by, society_id')
      .eq('id', complaintId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (cErr || !complaint) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    const isPrivileged = ['executive', 'secretary', 'president', 'admin'].includes(user.portalRole ?? user.role);
    if (complaint.raised_by !== user.id && !isPrivileged)
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const { data: attachments } = await sb
      .from('complaint_attachments')
      .select('id, storage_key, file_name, mime_type, file_size_bytes, created_at')
      .eq('complaint_id', complaintId)
      .order('created_at');

    const result = await Promise.all(
      (attachments ?? []).map(async (a) => {
        const url = await getDocumentDownloadUrl(a.storage_key);
        return { id: a.id, file_name: a.file_name, mime_type: a.mime_type, file_size_bytes: a.file_size_bytes, url };
      })
    );

    return Response.json(result);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
