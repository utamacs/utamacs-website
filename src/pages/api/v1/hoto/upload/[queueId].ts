export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — poll the status of an upload queue entry
// Auth: authenticated user who owns the upload, or admin
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });

    const queueId = params.queueId!;
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('upload_queue')
      .select('id, status, file_name, file_size_bytes, item_type, item_id, document_id, github_sha, error_message, created_at, last_attempt_at, attempts')
      .eq('id', queueId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) {
      return Response.json({ error: 'NOT_FOUND', message: 'Upload queue entry not found' }, { status: 404 });
    }

    // Only the uploader or an admin can see the status
    const uploadedBy = (data as any).uploaded_by as string | null;
    if (uploadedBy !== user.id && !user.isAdmin) {
      return Response.json({ error: 'FORBIDDEN', message: 'Access denied' }, { status: 403 });
    }

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
