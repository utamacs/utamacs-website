export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/documents/:id/history — returns all versions of a document (latest first)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid document id' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    // Fetch root document
    const { data: root, error: rootErr } = await sb
      .from('documents')
      .select('id, title, version, file_name, mime_type, file_size_bytes, storage_key, created_at, created_by')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (rootErr || !root) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Fetch all version-history records (children)
    const { data: versions } = await sb
      .from('documents')
      .select('id, version, file_name, mime_type, file_size_bytes, storage_key, created_at, created_by')
      .eq('parent_id', id)
      .eq('society_id', SOCIETY_ID)
      .order('version', { ascending: false });

    // Current version = root record (has latest storage_key)
    const currentEntry = {
      id: root.id,
      version: root.version,
      file_name: root.file_name,
      mime_type: root.mime_type,
      file_size_bytes: root.file_size_bytes,
      created_at: root.created_at,
      is_current: true,
      download_url: null as string | null,
    };
    try {
      currentEntry.download_url = await getDocumentDownloadUrl(root.storage_key);
    } catch { /* storage key may be missing */ }

    // Previous versions (archived copies, sorted desc by version number)
    const historyEntries = await Promise.all(
      (versions ?? []).map(async (v: any) => {
        let download_url: string | null = null;
        try { download_url = await getDocumentDownloadUrl(v.storage_key); } catch { /* skip */ }
        const { storage_key: _sk, ...rest } = v;
        return { ...rest, is_current: false, download_url };
      })
    );

    return Response.json([currentEntry, ...historyEntries]);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
