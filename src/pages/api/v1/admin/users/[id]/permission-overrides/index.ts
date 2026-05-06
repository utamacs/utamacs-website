export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { ALL_FEATURES } from '@lib/features';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list active overrides for a user, plus inherited permissions (admin only)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin access required' }, { status: 403 });

    const targetUserId = params.id!;
    const sb = getSupabaseServiceClient();

    const [profileRes, overridesRes] = await Promise.all([
      sb.from('profiles')
        .select('id, full_name, portal_role, committee_title')
        .eq('id', targetUserId)
        .eq('society_id', SOCIETY_ID)
        .single(),
      sb.from('user_feature_overrides')
        .select('*')
        .eq('user_id', targetUserId)
        .eq('society_id', SOCIETY_ID)
        .is('revoked_at', null)
        .order('granted_at', { ascending: false }),
    ]);

    if (!profileRes.data) {
      return Response.json({ error: 'NOT_FOUND', message: 'User not found' }, { status: 404 });
    }

    return Response.json({
      profile: profileRes.data,
      overrides: overridesRes.data ?? [],
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create or update a per-user feature override (admin only)
// Body: { feature, enabled, reason, expires_at? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin access required' }, { status: 403 });

    const targetUserId = params.id!;
    const body = await request.json() as {
      feature?: string;
      enabled?: boolean;
      reason?: string;
      expires_at?: string;
    };

    if (!body.feature || !ALL_FEATURES.includes(body.feature as typeof ALL_FEATURES[number])) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Valid feature is required' }, { status: 400 });
    }
    if (body.enabled === undefined) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'enabled (boolean) is required' }, { status: 400 });
    }
    if (!body.reason?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'reason is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: targetProfile } = await sb
      .from('profiles')
      .select('id')
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!targetProfile) {
      return Response.json({ error: 'NOT_FOUND', message: 'User not found' }, { status: 404 });
    }

    // Revoke any existing override for this feature first (upsert via soft-revoke + insert)
    await sb.from('user_feature_overrides')
      .update({ revoked_at: new Date().toISOString(), revoked_by: user.id })
      .eq('user_id', targetUserId)
      .eq('feature', body.feature)
      .eq('society_id', SOCIETY_ID)
      .is('revoked_at', null);

    const { data, error } = await sb.from('user_feature_overrides').insert({
      society_id: SOCIETY_ID,
      user_id: targetUserId,
      feature: body.feature,
      enabled: body.enabled,
      reason: body.reason.trim(),
      granted_by: user.id,
      expires_at: body.expires_at ?? null,
    }).select().single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'user_feature_overrides', resourceId: targetUserId,
      ip: extractClientIP(request),
      newValues: { feature: body.feature, enabled: body.enabled, reason: body.reason.trim() },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
