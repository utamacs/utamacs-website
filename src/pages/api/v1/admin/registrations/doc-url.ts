export const prerender = false;
// Returns a short-lived download URL for a registration request ID document
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'admin.registrations');

    const key = url.searchParams.get('key');
    if (!key) return Response.json({ error: 'VALIDATION', message: 'key parameter required' }, { status: 400 });

    if (key.includes('..') || key.startsWith('/')) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid key' }, { status: 400 });
    }

    const signed_url = await getDocumentDownloadUrl(key);

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'EXPORT', resourceType: 'registration_id_document', resourceId: key,
      ip: extractClientIP(request),
      newValues: { key },
    });

    return Response.json({ signed_url });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
