export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { commitDocument, getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { UUID_RE } from '@lib/constants';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const ROLE_ORDER: Record<string, number> = { member: 0, executive: 1, admin: 2 };

// GET /api/v1/documents/:id — single document detail + download URL
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid document id' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    const { data: doc, error } = await sb
      .from('documents')
      .select('id, title, description, category, file_name, mime_type, file_size_bytes, version, is_public, requires_role, tags, folder_id, is_archived, download_count, storage_key, created_by, created_at, updated_at')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .is('parent_id', null)
      .single();

    if (error || !doc) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const userLevel = user.isAdmin ? 2 : (ROLE_ORDER[user.portalRole ?? ''] ?? 0);
    const docLevel  = ROLE_ORDER[doc.requires_role ?? 'member'] ?? 0;
    if (docLevel > userLevel && !doc.is_public) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    let download_url: string | null = null;
    try { download_url = await getDocumentDownloadUrl(doc.storage_key); } catch { /* file may not exist yet */ }

    const { storage_key: _sk, ...rest } = doc;
    return Response.json({ ...rest, download_url });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

const ALLOWED_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
  'application/vnd.ms-excel': 'xls',
  'text/csv': 'csv',
};

// PUT /api/v1/documents/:id — upload a new version of an existing document
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'documents.manage');

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid document id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_DOCUMENTS_MB']);
    const maxBytes = ruleInt(rules, 'UPLOAD_LIMIT_DOCUMENTS_MB', 20) * 1024 * 1024;

    // Fetch the root document (must be parent_id IS NULL — can't version a version)
    const { data: doc, error: fetchErr } = await sb
      .from('documents')
      .select('id, title, category, version, storage_key, is_archived, parent_id, society_id')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !doc) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (doc.parent_id) return Response.json({ error: 'VALIDATION', message: 'Cannot version a version record; use the root document id' }, { status: 400 });
    if (doc.is_archived) return Response.json({ error: 'VALIDATION', message: 'Cannot add a version to an archived document' }, { status: 400 });

    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    const notes = sanitizePlainText(String(formData.get('notes') ?? '')).trim() || null;

    if (!file) return Response.json({ error: 'VALIDATION', message: 'No file provided' }, { status: 400 });

    const ext = ALLOWED_MIME[file.type];
    if (!ext) return Response.json({ error: 'VALIDATION', message: 'Unsupported file type' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    if (buffer.length > maxBytes) return Response.json({ error: 'VALIDATION', message: `File exceeds ${ruleInt(rules, 'UPLOAD_LIMIT_DOCUMENTS_MB', 20)} MB limit` }, { status: 400 });

    const newVersion = (doc.version ?? 1) + 1;
    const newKey = `members/${SOCIETY_ID}/${Date.now()}-${crypto.randomUUID()}.${ext}`;
    const result = await commitDocument(newKey, buffer, `docs: document ${id} version ${newVersion}`);

    // Archive the old storage_key into a version-history record
    const { error: insertErr } = await sb
      .from('documents')
      .insert({
        society_id: SOCIETY_ID,
        parent_id: doc.id,
        title: doc.title,
        category: doc.category,
        storage_key: doc.storage_key,  // preserves old file
        file_name: formData.get('file') instanceof File ? (formData.get('file') as File).name : file.name,
        mime_type: file.type,
        file_size_bytes: buffer.length,
        version: doc.version,           // old version number
        description: notes,
        is_public: false,
        requires_role: 'executive',
        is_archived: true,              // history records are archived
        created_by: user.id,
      });

    if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });

    // Update root with new storage key and bumped version
    const { data: updated, error: updateErr } = await sb
      .from('documents')
      .update({
        storage_key: result.githubPath,
        file_name: file.name,
        mime_type: file.type,
        file_size_bytes: buffer.length,
        version: newVersion,
      })
      .eq('id', id)
      .select('id, title, category, version, file_name, mime_type, file_size_bytes, created_at')
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'document', resourceId: id,
      ip: extractClientIP(request),
      oldValues: { version: doc.version, storage_key: doc.storage_key },
      newValues: { version: newVersion, file_name: file.name },
    });

    const download_url = await getDocumentDownloadUrl(result.githubPath);
    return Response.json({ ...updated, download_url });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
