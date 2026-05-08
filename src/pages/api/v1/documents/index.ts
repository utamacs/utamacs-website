export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { commitDocument, getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// Expanded category list matching migration 050
const VALID_CATEGORIES = [
  'Bylaws', 'Minutes', 'Financial', 'Legal',
  'Circulars', 'Forms', 'HOTO', 'Governance', 'Maintenance', 'Other',
] as const;

const VALID_ROLES = ['member', 'executive', 'admin'] as const;

const ALLOWED_MIME: Record<string, string> = {
  'application/pdf':  'pdf',
  'image/jpeg':       'jpg',
  'image/png':        'png',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':       'xlsx',
  'application/vnd.ms-excel': 'xls',
  'text/csv':         'csv',
};
const MAX_BYTES = 20 * 1024 * 1024; // 20 MB


export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const category  = url.searchParams.get('category') ?? '';
    const folder_id = url.searchParams.get('folder_id') ?? '';
    const q         = url.searchParams.get('q')?.trim() ?? '';
    const archived  = url.searchParams.get('archived') === 'true';

    let query = sb
      .from('documents')
      .select('id, title, description, category, file_name, mime_type, file_size_bytes, version, is_public, requires_role, storage_key, folder_id, tags, is_archived, download_count, created_by, created_at')
      .eq('society_id', SOCIETY_ID)
      .eq('is_archived', archived)
      .is('parent_id', null)
      .order('category')
      .order('title');

    // Role-based visibility
    if (['executive', 'admin'].includes(user.role) || user.isAdmin) {
      // See all
    } else {
      query = query.or('is_public.eq.true,requires_role.eq.member');
    }

    if (category && VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      query = query.eq('category', category);
    }
    if (folder_id && UUID_RE.test(folder_id)) {
      query = query.eq('folder_id', folder_id);
    } else if (folder_id === 'root') {
      query = query.is('folder_id', null);
    }
    if (q) query = query.ilike('title', `%${q}%`);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Generate download URLs in parallel
    const withUrls = await Promise.all(
      (data ?? []).map(async (doc: any) => {
        let download_url: string | null = null;
        try {
          download_url = await getDocumentDownloadUrl(doc.storage_key);
        } catch { /* skip — key may not exist yet */ }
        const { storage_key: _sk, ...rest } = doc;
        return { ...rest, download_url };
      })
    );

    return Response.json(withUrls);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — multipart file upload (documents.manage feature required)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'documents.manage');

    const formData = await request.formData();
    const file     = formData.get('file') as File | null;
    const title    = sanitizePlainText(String(formData.get('title') ?? '')).trim();
    const category = String(formData.get('category') ?? '');
    const description  = sanitizePlainText(String(formData.get('description') ?? '')).trim() || null;
    const requires_role = String(formData.get('requires_role') ?? 'member');
    const is_public    = formData.get('is_public') === 'true';
    const folder_id    = String(formData.get('folder_id') ?? '') || null;
    const tagsRaw      = String(formData.get('tags') ?? '');
    const tags: string[] = tagsRaw ? tagsRaw.split(',').map(t => t.trim()).filter(Boolean) : [];

    if (!file)  return Response.json({ error: 'VALIDATION', message: 'No file provided' }, { status: 400 });
    if (!title) return Response.json({ error: 'VALIDATION', message: 'Title is required' }, { status: 400 });
    if (!VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      return Response.json({ error: 'VALIDATION', message: `category must be one of: ${VALID_CATEGORIES.join(', ')}` }, { status: 400 });
    }
    if (!VALID_ROLES.includes(requires_role as typeof VALID_ROLES[number])) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid requires_role' }, { status: 400 });
    }
    if (folder_id && !UUID_RE.test(folder_id)) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid folder_id' }, { status: 400 });
    }

    const ext = ALLOWED_MIME[file.type];
    if (!ext) return Response.json({ error: 'VALIDATION', message: 'Unsupported file type (PDF, DOCX, XLSX, CSV, JPG, PNG allowed)' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    if (buffer.length > MAX_BYTES) {
      return Response.json({ error: 'VALIDATION', message: 'File exceeds 20 MB limit' }, { status: 400 });
    }

    const key = `members/${SOCIETY_ID}/${Date.now()}-${crypto.randomUUID()}.${ext}`;
    const result = await commitDocument(key, buffer, `docs: document library upload "${title}"`);

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('documents')
      .insert({
        society_id:    SOCIETY_ID,
        title,
        description,
        category,
        storage_key:   result.githubPath,
        file_name:     file.name,
        mime_type:     file.type,
        file_size_bytes: buffer.length,
        version:       1,
        is_public,
        requires_role,
        folder_id:     folder_id ?? null,
        tags,
        created_by:    user.id,
      })
      .select('id, title, category, file_name, mime_type, file_size_bytes, version, is_public, requires_role, folder_id, tags, created_at')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'document', resourceId: data.id,
      ip: extractClientIP(request), newValues: { category, title, file_name: file.name },
    });

    const download_url = await getDocumentDownloadUrl(result.githubPath);
    return Response.json({ ...data, download_url }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/documents?id=<uuid>  (documents.manage feature required)
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'documents.manage');

    const id = url.searchParams.get('id') ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Valid document id required' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    const { data: doc, error: fetchErr } = await sb
      .from('documents')
      .select('id, title, storage_key')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !doc) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Soft-archive rather than hard delete to preserve audit trail
    const { error } = await sb
      .from('documents')
      .update({ is_archived: true })
      .eq('id', id);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DELETE', resourceType: 'document', resourceId: id,
      ip: extractClientIP(request), oldValues: { title: doc.title },
    });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
