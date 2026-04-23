import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { featureFlagService, permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'feature_flags', 'read',
    );

    const sb = getSupabaseServiceClient();
    const [{ data: flags }, modules] = await Promise.all([
      sb.from('feature_flags').select('*').eq('society_id', SOCIETY_ID).order('module_key'),
      featureFlagService.getModules(SOCIETY_ID),
    ]);

    return new Response(JSON.stringify({ flags, modules }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PUT: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'feature_flags', 'update',
    );

    const body = await request.json() as { flag_id?: string; is_enabled?: boolean };
    if (!body.flag_id || typeof body.is_enabled !== 'boolean') {
      return new Response(JSON.stringify({ error: 'flag_id and is_enabled are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const updated = await featureFlagService.updateFlag(body.flag_id, body.is_enabled, user.id);
    return new Response(JSON.stringify(updated), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
