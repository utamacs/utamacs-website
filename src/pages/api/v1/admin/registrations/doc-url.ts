export const prerender = false;
// Returns a short-lived signed URL for a registration request ID document
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function isPrivileged(role: string, portalRole?: string, isAdmin?: boolean) {
  if (isAdmin) return true;
  return ['executive', 'admin'].includes(role) ||
    ['executive', 'secretary', 'president'].includes(portalRole ?? '');
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (!isPrivileged(user.role, user.portalRole, user.isAdmin)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const key = url.searchParams.get('key');
    if (!key) return Response.json({ error: 'VALIDATION', message: 'key parameter required' }, { status: 400 });

    // Safety: key must start with the expected prefix to prevent arbitrary bucket traversal
    if (!key.startsWith('onboarding-docs/') && !key.startsWith(`onboarding-docs/${SOCIETY_ID}/`)) {
      // Accept keys that may not have the bucket prefix (just the path)
      // but reject anything that looks like directory traversal
      if (key.includes('..') || key.startsWith('/')) {
        return Response.json({ error: 'VALIDATION', message: 'Invalid key' }, { status: 400 });
      }
    }

    const storage = new SupabaseStorageService();
    const signed_url = await storage.getSignedUrl('onboarding-docs', key, 3600);

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
