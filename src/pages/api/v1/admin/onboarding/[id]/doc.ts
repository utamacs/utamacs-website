export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { getDocumentDownloadUrl } from '@lib/utils/githubDocStore';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id      = params.id ?? '';
    const docType = new URL(request.url).searchParams.get('type') ?? 'ownership';

    const sb = getSupabaseServiceClient();
    const { data: req, error } = await sb
      .from('onboarding_requests')
      .select('id, ownership_doc_key, lease_doc_key, society_id')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !req) return Response.json({ error: 'NOT_FOUND', message: 'Request not found' }, { status: 404 });

    const key = docType === 'lease' ? req.lease_doc_key : req.ownership_doc_key;
    if (!key) return Response.json({ error: 'NOT_FOUND', message: 'No document attached' }, { status: 404 });

    const url = await getDocumentDownloadUrl(key);
    return Response.json({ url });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
